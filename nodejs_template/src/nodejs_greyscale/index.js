// package lambda; -- Node.js doesn't have packages, we use modules instead

// Import statements (equivalent to Java imports)
const AWS = require('aws-sdk');                    // AWS SDK for JavaScript
const sharp = require('sharp');                    // Image processing library (replaces Java's ImageIO/ColorConvertOp)
const Inspector = require('./Inspector');          // SAAF Inspector (same as: import saaf.Inspector;)

// Amazon S3 client using Lambda execution role credentials
// private final AmazonS3 s3 = AmazonS3ClientBuilder.defaultClient();
const s3 = new AWS.S3();

/**
 * GrayscaleHandler
 *
 * This Lambda function converts images uploaded to S3 into grayscale
 * and writes them to the "output/" prefix in the same bucket. It is intended
 * to be triggered by S3 events (new object created) in stage2.
 */

/**
 * Lambda entry point
 *
 * @param event   S3Event object containing metadata about the triggering S3 object
 * @param context Context object for logging and Lambda runtime info
 * @return A HashMap containing optional metrics (if Inspector is added) or simple message
 */
// public HashMap<String,Object> handleRequest(S3Event event, Context context) {
exports.handler = async (event, context) => {
    // Collect initial data.
    // Inspector inspector = new Inspector();
    const inspector = new Inspector();

    // inspector.inspectAll();
    inspector.inspectAll();

    // Extract S3 record information from the event
    // com.amazonaws.services.lambda.runtime.events.models.s3.S3EventNotification.S3Entity record =
    //         event.getRecords().get(0).getS3();
    const record = event.Records[0].s3;

    // Bucket name where the image resides
    // String bucket = record.getBucket().getName();
    const bucket = record.bucket.name;

    // Object key (full path inside bucket, e.g., "stage2/photo.jpg")
    // String key = record.getObject().getKey();
    const key = decodeURIComponent(record.object.key.replace(/\+/g, ' '));

    try {
        // ----------------------------------------------------------
        // 1. READ IMAGE FROM S3
        // ----------------------------------------------------------

        // S3Object obj = s3.getObject(bucket, key);
        // InputStream input = obj.getObjectContent();
        const getParams = {
            Bucket: bucket,
            Key: key
        };
        const s3Object = await s3.getObject(getParams).promise();

        // BufferedImage src = ImageIO.read(input);
        const inputBuffer = s3Object.Body;

        // ----------------------------------------------------------
        // 2. CONVERT IMAGE TO GRAYSCALE
        // ----------------------------------------------------------

        // BufferedImage gray = toGrayscale(src);
        const grayBuffer = await toGrayscale(inputBuffer);

        // ----------------------------------------------------------
        // 3. ENCODE GRAYSCALE IMAGE INTO BYTES
        // ----------------------------------------------------------

        // byte[] bytes = bufferedImageToBytes(gray);
        // Sharp already returns bytes, so grayBuffer is ready to use

        // ----------------------------------------------------------
        // 4. WRITE PROCESSED IMAGE TO OUTPUT PREFIX
        // ----------------------------------------------------------

        // String filename = key.substring(key.lastIndexOf('/') + 1);
        const filename = key.substring(key.lastIndexOf('/') + 1);

        // Pipeline tracking for CloudWatch metrics
        inspector.addAttribute("image_id", filename);
        inspector.addAttribute("pipeline_stage", "greyscale");

        // String newKey = "output/" + filename;
        const newKey = `output/${filename}`;

        // ObjectMetadata meta = new ObjectMetadata();
        // meta.setContentLength(bytes.length);
        // meta.setContentType("image/jpeg");
        const putParams = {
            Bucket: bucket,
            Key: newKey,
            Body: grayBuffer,
            ContentType: 'image/jpeg',
            ContentLength: grayBuffer.length
        };

        // s3.putObject(bucket, newKey, new ByteArrayInputStream(bytes), meta);
        await s3.putObject(putParams).promise();

        // ****************END FUNCTION IMPLEMENTATION***************************

        // Collect final information such as total runtime and cpu deltas.
        // inspector.inspectAllDeltas();
        inspector.addAttribute("bucket name", bucket);
        inspector.addAttribute("subfolder", getParams.Key);
        inspector.addAttribute("file", filename)
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
        // Re-throw exceptions as RuntimeException for Lambda to log
        // throw new RuntimeException(e);
        console.error("Error processing image:", e);
        throw new Error(e.message);
    }
};

// ---------------- Helper Methods --------------------

/**
 * Convert a BufferedImage to grayscale efficiently using ColorConvertOp.
 *
 * @param inputBuffer Buffer containing the image data
 * @return Buffer containing the grayscale image as JPEG
 */
// private BufferedImage toGrayscale(BufferedImage src) {
async function toGrayscale(inputBuffer) {
    // int w = src.getWidth();
    // int h = src.getHeight();
    // Sharp handles dimensions internally, no need to get them explicitly

    // Create destination grayscale image
    // BufferedImage gray = new BufferedImage(w, h, BufferedImage.TYPE_BYTE_GRAY);

    // Use ColorConvertOp to convert color space to grayscale
    // ColorConvertOp op = new ColorConvertOp(ColorSpace.getInstance(ColorSpace.CS_GRAY), null);
    // op.filter(src, gray);

    // Sharp combines all these steps into one fluent call
    // .grayscale() is equivalent to ColorConvertOp with CS_GRAY
    const grayBuffer = await sharp(inputBuffer)
        .grayscale()             // Convert to grayscale (equivalent to ColorConvertOp with CS_GRAY)
        .jpeg()                  // Encode as JPEG (equivalent to bufferedImageToBytes)
        .toBuffer();             // Convert to byte array

    // return gray;
    return grayBuffer;
}

// /**
//  * Convert a BufferedImage to a JPEG byte array for S3 upload.
//  *
//  * @param img BufferedImage input
//  * @return byte array containing JPEG image
//  * @throws IOException
//  */
// private byte[] bufferedImageToBytes(BufferedImage img) throws IOException {
//     java.io.ByteArrayOutputStream baos = new java.io.ByteArrayOutputStream();
//     ImageIO.write(img, "jpg", baos);
//     return baos.toByteArray();
// }
// NOTE: In the Node.js version, this is combined into the toGrayscale() function
// using Sharp's .jpeg().toBuffer() chain. Sharp handles the encoding internally.