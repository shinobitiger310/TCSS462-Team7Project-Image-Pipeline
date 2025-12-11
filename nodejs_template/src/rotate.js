const {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
} = require("@aws-sdk/client-s3");
const sharp = require("sharp");
const Inspector = require("./Inspector");
const config = require("./config");

const s3Client = new S3Client();

/**
 * RotateHandler - Dual Mode Support
 *
 * This Lambda function rotates images by 180 degrees and supports TWO invocation modes:
 *
 * MODE 1 - S3 Event Trigger (Original Behavior):
 *      - Triggered automatically when images are uploaded to S3 input/ prefix
 *      - Reads from S3, processes, writes back to S3 stage1/ prefix
 *      - Event contains 'Records' array with S3 metadata
 *
 * MODE 2 - Direct Invocation (FaaS Runner Pipeline):
 *      - Invoked directly with image data in the payload
 *      - Used for synchronous pipelines and performance testing
 *      - Event contains 'image_data' (base64) or 's3_bucket'/'s3_key'
 *      - Returns processed image and metrics in response
 *
 * Lambda entry point - automatically detects invocation mode.
 */
exports.handler = async (event) => {
  const inspector = new Inspector();
  inspector.inspectAll();

  // DETECT INVOCATION MODE
  if (event.Records && event.Records.length > 0) {
    // MODE 1: S3 Event Trigger
    return handleS3Event(event, inspector);
  } else {
    // MODE 2: Direct Invocation (FaaS Runner)
    return handleDirectInvocation(event, inspector);
  }
};

/**
 * Handle S3 event-triggered invocation (original behavior).
 * Reads from S3, processes, writes back to S3.
 */
async function handleS3Event(event, inspector) {
  const inputBucket = event.Records[0].s3.bucket.name;
  const inputKey = decodeURIComponent(event.Records[0].s3.object.key.replace(/\+/g, ' '));
  const filename = inputKey.split('/').pop();

  // Output bucket from config
  const outputBucket = config.buckets.base;
  const outputKey = config.buckets.stage1 + filename;

  try {
    // ----------------------------------------------------------
    // 1. READ IMAGE FROM S3
    // ----------------------------------------------------------

    const response = await s3Client.send(
      new GetObjectCommand({
        Bucket: inputBucket,
        Key: inputKey,
      })
    );

    const chunks = [];
    for await (const chunk of response.Body) {
      chunks.push(chunk);
    }
    const imageBuffer = Buffer.concat(chunks);

    // ----------------------------------------------------------
    // 2. ROTATE IMAGE BY 180 DEGREES
    // ----------------------------------------------------------

    const rotatedImageBuffer = await sharp(imageBuffer).rotate(180).toBuffer();

    // ----------------------------------------------------------
    // 3. WRITE PROCESSED IMAGE TO NEXT STAGE IN PIPELINE
    // ----------------------------------------------------------

    await s3Client.send(
      new PutObjectCommand({
        Bucket: outputBucket,
        Key: outputKey,
        Body: rotatedImageBuffer,
        ContentType: response.ContentType || "image/jpeg",
      })
    );

    // ****************END FUNCTION IMPLEMENTATION***************************

    inspector.addAttribute("inputBucket", inputBucket);
    inspector.addAttribute("outputBucket", outputBucket);
    inspector.addAttribute("inputKey", inputKey);
    inspector.addAttribute("outputKey", outputKey);
    inspector.addAttribute("message", "Image rotated successfully");

    inspector.inspectAllDeltas();
    const result = inspector.finish();
    console.log(JSON.stringify(result));
    return result;
  } catch (error) {
    console.error("ERROR in S3 event handler:", error);

    inspector.addAttribute("message", "Error rotating image");
    inspector.addAttribute("error", error.message);

    inspector.inspectAllDeltas();
    const result = inspector.finish();
    console.log(JSON.stringify(result));
    return result;
  }
}

/**
 * Handle direct invocation for FaaS Runner pipelines.
 * Accepts image data in payload, processes it, returns result with metrics.
 *
 * Expected event format:
 * {
 *     "image_data": "base64_encoded_image",  // Option 1: Direct base64 data
 *     OR
 *     "s3_bucket": "bucket-name",            // Option 2: S3 reference
 *     "s3_key": "path/to/image.jpg",
 *
 *     "operation": "rotate"                  // Operation name (for logging)
 * }
 *
 * Returns:
 * {
 *     "image_data": "base64_encoded_rotated_image",
 *     "operation": "rotate",
 *     "success": true,
 *     "runtime": 123,                        // Inspector metrics
 *     "version": "1.0",                      // SAAF version (required by FaaS Runner)
 *     ... other Inspector metrics ...
 * }
 */
async function handleDirectInvocation(event, inspector) {
  try {
    // ----------------------------------------------------------
    // 1. READ IMAGE FROM PAYLOAD OR S3
    // ----------------------------------------------------------

    let imageBuffer;

    if (event.image_data) {
      // Option 1: Image data provided as base64 in payload
      imageBuffer = Buffer.from(event.image_data, 'base64');
      inspector.addAttribute("input_source", "payload");

    } else if (event.s3_bucket && event.s3_key) {
      // Option 2: S3 reference provided
      const response = await s3Client.send(
        new GetObjectCommand({
          Bucket: event.s3_bucket,
          Key: event.s3_key,
        })
      );

      const chunks = [];
      for await (const chunk of response.Body) {
        chunks.push(chunk);
      }
      imageBuffer = Buffer.concat(chunks);

      inspector.addAttribute("input_source", "s3");
      inspector.addAttribute("s3_bucket", event.s3_bucket);
      inspector.addAttribute("s3_key", event.s3_key);

    } else {
      throw new Error("Missing required fields: either 'image_data' or ('s3_bucket' and 's3_key')");
    }

    // Add operation info
    const operation = event.operation || "rotate";
    inspector.addAttribute("operation", operation);

    // ----------------------------------------------------------
    // 2. ROTATE IMAGE BY 180 DEGREES
    // ----------------------------------------------------------

    const rotatedImageBuffer = await sharp(imageBuffer).rotate(180).toBuffer();

    // ----------------------------------------------------------
    // 3. ENCODE ROTATED IMAGE BACK INTO BASE64
    // ----------------------------------------------------------

    const resultB64 = rotatedImageBuffer.toString('base64');

    // Add result info
    inspector.addAttribute("output_size", rotatedImageBuffer.length);
    inspector.addAttribute("success", true);

    // ----------------------------------------------------------
    // 4. COLLECT METRICS AND RETURN RESPONSE
    // ----------------------------------------------------------

    inspector.inspectAllDeltas();
    const metrics = inspector.finish();

    // Add processed image to response
    metrics.image_data = resultB64;
    metrics.operation = operation;

    // Log metrics without image_data to avoid cluttering logs
    const metricsForLog = { ...metrics };
    delete metricsForLog.image_data;
    console.log("INSPECTOR METRICS (without image_data):", JSON.stringify(metricsForLog));

    return metrics;

  } catch (error) {
    console.error("ERROR in direct invocation handler:", error);

    // Return error with metrics
    inspector.addAttribute("success", false);
    inspector.addAttribute("error", error.message);
    inspector.inspectAllDeltas();
    return inspector.finish();
  }
}
