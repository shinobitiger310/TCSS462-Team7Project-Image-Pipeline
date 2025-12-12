// package lambda; -- Node.js doesn't have packages, we use modules instead

// Import statements (equivalent to Java imports)
const AWS = require('aws-sdk');                    // AWS SDK for JavaScript
const sharp = require('sharp');                    // Image processing library (replaces Java's ImageIO/Graphics2D)
const Inspector = require('./Inspector');          // SAAF Inspector (same as: import saaf.Inspector;)

// Amazon S3 client using Lambda's execution role credentials
// private final AmazonS3 s3 = AmazonS3ClientBuilder.defaultClient();
const s3 = new AWS.S3();

/**
 * ResizeHandler
 *
 * This Lambda function resizes images uploaded to S3 by 150% and writes
 * them to the "stage2/" prefix in the same bucket. It is intended to be
 * triggered by S3 events (new object created) in stage1.
 */

/**
 * Lambda entry point.
 *
 * @param event   S3Event object containing metadata about the triggering S3 object
 * @param context Context object for logging and Lambda runtime info
 * @return A string message confirming where the processed image was written
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

    // Bucket name where the image lives
    // String bucket = record.getBucket().getName();
    const bucket = record.bucket.name;

    // Object key (full path inside bucket, e.g., "stage1/photo.jpg")
    // String key = record.getObject().getKey();
    const key = decodeURIComponent(record.object.key.replace(/\+/g, ' '));

    try {
        // ----------------------------------------------------------
        // 1. READ IMAGE FROM S3
        // ----------------------------------------------------------

        // Download the S3 object as an InputStream
        // S3Object obj = s3.getObject(bucket, key);
        // InputStream input = obj.getObjectContent();
        const getParams = {
            Bucket: bucket,
            Key: key
        };
        const s3Object = await s3.getObject(getParams).promise();

        // Convert the stream into a BufferedImage for processing
        // BufferedImage src = ImageIO.read(input);
        const inputBuffer = s3Object.Body;

        // ----------------------------------------------------------
        // 2. RESIZE IMAGE TO 150%
        // ----------------------------------------------------------

        // BufferedImage resized = resize(src);
        const resizedBuffer = await resize(inputBuffer);

        // ----------------------------------------------------------
        // 3. ENCODE RESIZED IMAGE INTO BYTES
        // ----------------------------------------------------------

        // byte[] bytes = bufferedImageToBytes(resized);
        // Sharp already returns bytes, so resizedBuffer is ready to use

        // ----------------------------------------------------------
        // 4. WRITE PROCESSED IMAGE TO NEXT STAGE IN PIPELINE
        // ----------------------------------------------------------

        // Extract just the filename from the key (e.g., "photo.jpg")
        // String filename = key.substring(key.lastIndexOf('/') + 1);
        const filename = key.substring(key.lastIndexOf('/') + 1);

        // Pipeline tracking for CloudWatch metrics
        inspector.addAttribute("image_id", filename);
        inspector.addAttribute("pipeline_stage", "resize");

        // Next-stage prefix where the next handler listens
        // String newKey = "stage2/" + filename;
        const newKey = `stage2/${filename}`;

        // Metadata so S3 knows the file size + content type
        // ObjectMetadata meta = new ObjectMetadata();
        // meta.setContentLength(bytes.length);
        // meta.setContentType("image/jpeg");
        const putParams = {
            Bucket: bucket,
            Key: newKey,
            Body: resizedBuffer,
            ContentType: 'image/jpeg',
            ContentLength: resizedBuffer.length
        };

        // Upload the resized image back to S3
        // s3.putObject(bucket, newKey, new ByteArrayInputStream(bytes), meta);
        await s3.putObject(putParams).promise();

        // ****************END FUNCTION IMPLEMENTATION***************************

        // Collect final information such as total runtime and cpu deltas.
        // inspector.inspectAllDeltas();

        inspector.addAttribute("bucket name", bucket);
        inspector.addAttribute("new file", newKey)
        inspector.addAttribute("message", "Image resized successfully");

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
        // Re-throw exceptions as RuntimeException so Lambda logs it as an error
        // throw new RuntimeException(e);
        console.error("Error processing image:", e);
        throw new Error(e.message);
    }
};

// ---------------- Helper Functions --------------------

/**
 * Resize an image to 150% of its original width and height.
 *
 * @param inputBuffer Buffer containing the image data
 * @return Buffer containing the resized image as JPEG
 */
// private BufferedImage resize(BufferedImage src) {
async function resize(inputBuffer) {
    // double resizeFactor = 1.5;
    const resizeFactor = 1.5;

    // int origW = src.getWidth();
    // int origH = src.getHeight();
    // Get original dimensions using Sharp's metadata
    const metadata = await sharp(inputBuffer).metadata();
    const origW = metadata.width;
    const origH = metadata.height;

    // int newW = (int) (origW * resizeFactor);
    // int newH = (int) (origH * resizeFactor);
    const newW = Math.floor(origW * resizeFactor);
    const newH = Math.floor(origH * resizeFactor);

    // Create a new BufferedImage for the resized image
    // BufferedImage dst = new BufferedImage(newW, newH, src.getType());
    // Graphics2D g = dst.createGraphics();

    // Use bilinear interpolation for smooth scaling
    // g.setRenderingHint(RenderingHints.KEY_INTERPOLATION,
    //                    RenderingHints.VALUE_INTERPOLATION_BILINEAR);

    // Draw the original image scaled to new dimensions
    // g.drawImage(src, 0, 0, newW, newH, null);
    // g.dispose();

    // Sharp combines all these steps into one fluent call
    // kernel: 'linear' is equivalent to VALUE_INTERPOLATION_BILINEAR
    const resizedBuffer = await sharp(inputBuffer)
        .resize(newW, newH, {
            kernel: sharp.kernel.linear    // Bilinear interpolation (equivalent to VALUE_INTERPOLATION_BILINEAR)
        })
        .jpeg()                            // Encode as JPEG (equivalent to bufferedImageToBytes)
        .toBuffer();                       // Convert to byte array

    // return dst;
    return resizedBuffer;
}

// /**
//  * Convert a BufferedImage to a byte array in JPEG format.
//  *
//  * @param img BufferedImage to convert
//  * @return byte array of JPEG image
//  * @throws IOException
//  */
// private byte[] bufferedImageToBytes(BufferedImage img) throws IOException {
//     java.io.ByteArrayOutputStream baos = new java.io.ByteArrayOutputStream();
//     ImageIO.write(img, "jpg", baos);
//     return baos.toByteArray();
// }
// NOTE: In the Node.js version, this is combined into the resize() function
// using Sharp's .jpeg().toBuffer() chain. Sharp handles the encoding internally.