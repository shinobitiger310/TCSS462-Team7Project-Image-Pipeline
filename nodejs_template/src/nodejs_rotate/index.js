// package lambda; -- Node.js doesn't have packages, we use modules instead

// Import statements (equivalent to Java imports)
const AWS = require('aws-sdk');                    // AWS SDK for JavaScript
const sharp = require('sharp');                    // Image processing library (replaces Java's ImageIO/Graphics2D)
const Inspector = require('./Inspector');          // SAAF Inspector (same as: import saaf.Inspector;)

// Create an S3 client using the Lambda execution role credentials.
// This client is used for both reading and writing objects in S3.
const s3 = new AWS.S3();

/**
 * Lambda entry point.
 *
 * event:
 *      - Contains information about the S3 object that triggered this Lambda.
 *      - Includes bucket name and object key (file path).
 *
 * context:
 *      - Provides metadata such as remaining time, request ID, and logger.
 */
exports.handler = async (event, context) => {
    // Collect initial data.
    // Inspector inspector = new Inspector();
    const inspector = new Inspector();

    // inspector.inspectAll();
    inspector.inspectAll();

    // Extract metadata about the uploaded S3 object from the event.
    // com.amazonaws.services.lambda.runtime.events.models.s3.S3EventNotification.S3Entity record =
    //         event.getRecords().get(0).getS3();
    const record = event.Records[0].s3;

    // Bucket name where the triggering image lives.
    // String bucket = record.getBucket().getName();
    const bucket = record.bucket.name;

    // Key is the full path inside the bucket (e.g. "input/photo.jpg").
    // String key = record.getObject().getKey();
    const key = decodeURIComponent(record.object.key.replace(/\+/g, ' '));

    try {
        // ----------------------------------------------------------
        // 1. READ IMAGE FROM S3
        // ----------------------------------------------------------

        // Get the object from S3 as a stream.
        // S3Object obj = s3.getObject(bucket, key);
        // InputStream input = obj.getObjectContent();
        const getParams = {
            Bucket: bucket,
            Key: key
        };
        const s3Object = await s3.getObject(getParams).promise();

        // The image bytes (equivalent to InputStream)
        // BufferedImage src = ImageIO.read(input);
        const inputBuffer = s3Object.Body;

        // ----------------------------------------------------------
        // 2. ROTATE IMAGE BY 180 DEGREES
        // ----------------------------------------------------------

        // BufferedImage rotated = rotate(src);
        const rotatedBuffer = await rotate(inputBuffer);

        // ----------------------------------------------------------
        // 3. ENCODE ROTATED IMAGE BACK INTO JPEG BYTES
        // ----------------------------------------------------------

        // byte[] bytes = bufferedImageToBytes(rotated);
        // Sharp already returns bytes, so rotatedBuffer is ready to use

        // ----------------------------------------------------------
        // 4. WRITE PROCESSED IMAGE TO NEXT STAGE IN PIPELINE
        // ----------------------------------------------------------

        // Extract just the filename from the original key.
        // Example: "input/photo.jpg" → "photo.jpg"
        // String filename = key.substring(key.lastIndexOf('/') + 1);
        const filename = key.substring(key.lastIndexOf('/') + 1);

        // Pipeline tracking for CloudWatch metrics
        inspector.addAttribute("image_id", filename);
        inspector.addAttribute("pipeline_stage", "rotate");

        // Next-stage prefix where ResizeHandler listens.
        // String newKey = "stage1/" + filename;
        const newKey = `stage1/${filename}`;

        // Metadata so S3 knows the file size + content type.
        // ObjectMetadata meta = new ObjectMetadata();
        // meta.setContentLength(bytes.length);
        // meta.setContentType("image/jpeg");
        const putParams = {
            Bucket: bucket,
            Key: newKey,
            Body: rotatedBuffer,
            ContentType: 'image/jpeg',
            ContentLength: rotatedBuffer.length
        };

        // Upload the processed (rotated) image back to S3.
        // s3.putObject(bucket, newKey, new ByteArrayInputStream(bytes), meta);
        await s3.putObject(putParams).promise();

        // Create and populate a separate response object for function output. (OPTIONAL)
        // Response response = new Response();
        // response.setValue("Bucket:" + bucketname + " filename:" + filename + " size:" + bytes.length);
        // inspector.consumeResponse(response);

        // ****************END FUNCTION IMPLEMENTATION***************************

        // Collect final information such as total runtime and cpu deltas.
        // inspector.inspectAllDeltas();

        inspector.addAttribute("bucket name", bucket);
        inspector.addAttribute("new file", newKey)
        inspector.addAttribute("message", "Image rotated successfully");

        inspector.inspectAllDeltas();

        // Get the metrics as a HashMap
        // HashMap<String, Object> metrics = inspector.finish();
        const metrics = inspector.finish();

        // Log them to CloudWatch
        // context.getLogger().log("INSPECTOR METRICS: " + metrics.toString());
        console.log("INSPECTOR METRICS: " + JSON.stringify(metrics));

        // return metrics;
        return metrics;

    } catch (e) {
        // throw new RuntimeException(e);
        console.error("Error processing image:", e);
        throw new Error(e.message);
    }
};

// ----------------------------------------------------------------------
// Helper method to rotate the image 180 degrees around its center.
//
// Why this transform?
//   - 180° rotation is equivalent to flipping horizontally + vertically.
//   - In Sharp, we use .rotate(180) which handles the transformation internally.
//   - The Java version uses AffineTransform with:
//         translate(w, h)
//         rotate(π radians)
//     to move the origin so the rotation happens around the image center.
// ----------------------------------------------------------------------
// private BufferedImage rotate(BufferedImage src) {
async function rotate(inputBuffer) {
    // Amount to rotate in radians (180 degrees).
    // double rotateAmount = Math.PI;
    const rotateAmount = 180; // Sharp uses degrees, not radians

    // int w = src.getWidth();
    // int h = src.getHeight();
    // Sharp handles dimensions internally

    // Destination image with same dimensions as the original.
    // BufferedImage dst = new BufferedImage(w, h, src.getType());
    // Graphics2D g = dst.createGraphics();

    // Build a transformation that rotates the image 180°.
    // AffineTransform transform = new AffineTransform();

    // Translate the image so the rotation pivot is correct.
    // transform.translate(w, h);

    // Rotate by 180 degrees (π radians).
    // transform.rotate(rotateAmount);

    // Apply the transformation and draw the rotated image.
    // g.drawImage(src, transform, null);
    // g.dispose();

    // Sharp combines all these steps into one fluent call
    const rotatedBuffer = await sharp(inputBuffer)
        .rotate(rotateAmount)    // Rotate by 180 degrees
        .jpeg()                  // Encode as JPEG (equivalent to bufferedImageToBytes)
        .toBuffer();             // Convert to byte array

    // return dst;
    return rotatedBuffer;
}

// ----------------------------------------------------------------------
// Convert a BufferedImage back into a JPEG stored in a byte array.
// This byte array can then be uploaded directly to S3.
// ----------------------------------------------------------------------
// private byte[] bufferedImageToBytes(BufferedImage img) throws IOException {
//     java.io.ByteArrayOutputStream baos = new java.io.ByteArrayOutputStream();
//     ImageIO.write(img, "jpg", baos);
//     return baos.toByteArray();
// }
// NOTE: In the Node.js version, this is combined into the rotate() function
// using Sharp's .jpeg().toBuffer() chain. Sharp handles the encoding internally.