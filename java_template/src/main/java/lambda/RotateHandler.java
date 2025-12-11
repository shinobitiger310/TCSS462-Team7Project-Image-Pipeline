package lambda;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.S3Event;

import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.model.*;

import saaf.Inspector;

import javax.imageio.ImageIO;
import java.awt.Graphics2D;
import java.awt.geom.AffineTransform;
import java.awt.image.BufferedImage;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.io.IOException;

/**
 * RotateHandler - Dual Mode Support
 *
 * This Lambda function rotates images by 180 degrees and supports TWO invocation modes:
 *
 * MODE 1 - S3 Event Trigger (Original Behavior):
 *      - Triggered automatically when images are uploaded to S3 input/ prefix
 *      - Reads from S3, processes, writes back to S3 stage1/ prefix
 *      - Input type: S3Event with Records array
 *
 * MODE 2 - Direct Invocation (FaaS Runner Pipeline):
 *      - Invoked directly with image data in the payload
 *      - Used for synchronous pipelines and performance testing
 *      - Input type: Map with "image_data" (base64) or "s3_bucket"/"s3_key"
 *      - Returns processed image and metrics in response
 */
public class RotateHandler implements RequestHandler<Object, HashMap<String,Object>> {

    // Create an S3 client using the Lambda execution role credentials.
    // This client is used for both reading and writing objects in S3.
    private final AmazonS3 s3 = AmazonS3ClientBuilder.defaultClient();

    /**
     * Lambda entry point - automatically detects invocation mode.
     */
    @Override
    public HashMap<String, Object> handleRequest(Object input, Context context) {
        // Collect initial data.
        Inspector inspector = new Inspector();
        inspector.inspectAll();

        // DETECT INVOCATION MODE
        if (input instanceof S3Event) {
            // MODE 1: S3 Event Trigger
            return handleS3Event((S3Event) input, context, inspector);
        } else if (input instanceof Map) {
            // MODE 2: Direct Invocation (FaaS Runner)
            @SuppressWarnings("unchecked")
            Map<String, Object> event = (Map<String, Object>) input;
            return handleDirectInvocation(event, context, inspector);
        } else {
            throw new IllegalArgumentException("Unsupported input type: " + input.getClass().getName());
        }
    }

    /**
     * Handle S3 event-triggered invocation (original behavior).
     * Reads from S3, processes, writes back to S3.
     */
    private HashMap<String, Object> handleS3Event(S3Event event, Context context, Inspector inspector) {

        // Extract metadata about the uploaded S3 object from the event.
        com.amazonaws.services.lambda.runtime.events.models.s3.S3EventNotification.S3Entity record =
                event.getRecords().get(0).getS3();

        // Bucket name where the triggering image lives.
        String bucket = record.getBucket().getName();

        // Key is the full path inside the bucket (e.g. "input/photo.jpg").
        String key = record.getObject().getKey();

        try {
            // ----------------------------------------------------------
            // 1. READ IMAGE FROM S3
            // ----------------------------------------------------------

            // Get the object from S3 as a stream.
            S3Object obj = s3.getObject(bucket, key);
            InputStream input = obj.getObjectContent();

            // Convert the downloaded bytes into a Java BufferedImage.
            BufferedImage src = ImageIO.read(input);

            // ----------------------------------------------------------
            // 2. ROTATE IMAGE BY 180 DEGREES
            // ----------------------------------------------------------

            BufferedImage rotated = rotate(src);

            // ----------------------------------------------------------
            // 3. ENCODE ROTATED IMAGE BACK INTO JPEG BYTES
            // ----------------------------------------------------------

            byte[] bytes = bufferedImageToBytes(rotated);

            // ----------------------------------------------------------
            // 4. WRITE PROCESSED IMAGE TO NEXT STAGE IN PIPELINE
            // ----------------------------------------------------------

            // Extract just the filename from the original key.
            // Example: "input/photo.jpg" → "photo.jpg"
            String filename = key.substring(key.lastIndexOf('/') + 1);

            // Next-stage prefix where ResizeHandler listens.
            String newKey = "stage1/" + filename;

            // Metadata so S3 knows the file size + content type.
            ObjectMetadata meta = new ObjectMetadata();
            meta.setContentLength(bytes.length);
            meta.setContentType("image/jpeg");

            // Upload the processed (rotated) image back to S3.
            s3.putObject(bucket, newKey, new ByteArrayInputStream(bytes), meta);

            //Create and populate a separate response object for function output. (OPTIONAL)
            //Response response = new Response();
            //response.setValue("Bucket:" + bucketname + " filename:" + filename + " size:" + bytes.length);

            //inspector.consumeResponse(response);
        
            //****************END FUNCTION IMPLEMENTATION***************************
            
            //Collect final information such as total runtime and cpu deltas.
            inspector.inspectAllDeltas();

            // Get the metrics as a HashMap
            HashMap<String, Object> metrics = inspector.finish();

            // Log them to CloudWatch
            context.getLogger().log("INSPECTOR METRICS: " + metrics.toString());

            return metrics;
        } catch (Exception e) {
            context.getLogger().log("ERROR in S3 event handler: " + e.getMessage());
            throw new RuntimeException(e);
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
     *     "version": 1.0,                        // SAAF version (required by FaaS Runner)
     *     ... other Inspector metrics ...
     * }
     */
    private HashMap<String, Object> handleDirectInvocation(Map<String, Object> event, Context context, Inspector inspector) {
        try {
            // ----------------------------------------------------------
            // 1. READ IMAGE FROM PAYLOAD OR S3
            // ----------------------------------------------------------

            BufferedImage src;

            if (event.containsKey("image_data")) {
                // Option 1: Image data provided as base64 in payload
                String imageB64 = (String) event.get("image_data");
                byte[] imageBytes = Base64.getDecoder().decode(imageB64);
                src = ImageIO.read(new ByteArrayInputStream(imageBytes));
                inspector.addAttribute("input_source", "payload");

            } else if (event.containsKey("s3_bucket") && event.containsKey("s3_key")) {
                // Option 2: S3 reference provided
                String bucket = (String) event.get("s3_bucket");
                String key = (String) event.get("s3_key");

                S3Object obj = s3.getObject(bucket, key);
                InputStream input = obj.getObjectContent();
                src = ImageIO.read(input);

                inspector.addAttribute("input_source", "s3");
                inspector.addAttribute("s3_bucket", bucket);
                inspector.addAttribute("s3_key", key);

            } else {
                throw new IllegalArgumentException("Missing required fields: either 'image_data' or ('s3_bucket' and 's3_key')");
            }

            // Add operation info
            String operation = event.containsKey("operation") ? (String) event.get("operation") : "rotate";
            inspector.addAttribute("operation", operation);

            // ----------------------------------------------------------
            // 2. ROTATE IMAGE BY 180 DEGREES
            // ----------------------------------------------------------

            BufferedImage rotated = rotate(src);

            // ----------------------------------------------------------
            // 3. ENCODE ROTATED IMAGE BACK INTO BASE64
            // ----------------------------------------------------------

            byte[] imageBytes = bufferedImageToBytes(rotated);
            String resultB64 = Base64.getEncoder().encodeToString(imageBytes);

            // Add result info
            inspector.addAttribute("output_size", imageBytes.length);
            inspector.addAttribute("success", true);

            // ----------------------------------------------------------
            // 4. COLLECT METRICS AND RETURN RESPONSE
            // ----------------------------------------------------------

            inspector.inspectAllDeltas();
            HashMap<String, Object> metrics = inspector.finish();

            // Add processed image to response
            metrics.put("image_data", resultB64);
            metrics.put("operation", operation);

            context.getLogger().log("INSPECTOR METRICS (without image_data): " +
                metrics.entrySet().stream()
                    .filter(e -> !e.getKey().equals("image_data"))
                    .collect(java.util.stream.Collectors.toMap(Map.Entry::getKey, Map.Entry::getValue)));

            return metrics;

        } catch (Exception e) {
            context.getLogger().log("ERROR in direct invocation handler: " + e.getMessage());

            // Return error with metrics
            inspector.addAttribute("success", false);
            inspector.addAttribute("error", e.getMessage());
            inspector.inspectAllDeltas();
            return inspector.finish();
        }
    }

    // ----------------------------------------------------------------------
    // Helper method to rotate the image 180 degrees around its center.
    //
    // Why this transform?
    //   - 180° rotation is equivalent to flipping horizontally + vertically.
    //   - The affine transform:
    //         translate(w, h)
    //         rotate(π radians)
    //     moves the origin so the rotation happens around the image center.
    // ----------------------------------------------------------------------
    private BufferedImage rotate(BufferedImage src) {
        // Amount to rotate in radians (180 degrees).
        double rotateAmount = Math.PI;

        int w = src.getWidth();
        int h = src.getHeight();

        // Destination image with same dimensions as the original.
        BufferedImage dst = new BufferedImage(w, h, src.getType());
        Graphics2D g = dst.createGraphics();

        // Build a transformation that rotates the image 180°.
        AffineTransform transform = new AffineTransform();

        // Translate the image so the rotation pivot is correct.
        transform.translate(w, h);

        // Rotate by 180 degrees (π radians).
        transform.rotate(rotateAmount);

        // Apply the transformation and draw the rotated image.
        g.drawImage(src, transform, null);
        g.dispose();

        return dst;
    }

    // ----------------------------------------------------------------------
    // Convert a BufferedImage back into a JPEG stored in a byte array.
    // This byte array can then be uploaded directly to S3.
    // ----------------------------------------------------------------------
    private byte[] bufferedImageToBytes(BufferedImage img) throws IOException {
        java.io.ByteArrayOutputStream baos = new java.io.ByteArrayOutputStream();
        ImageIO.write(img, "jpg", baos);
        return baos.toByteArray();
    }
}
