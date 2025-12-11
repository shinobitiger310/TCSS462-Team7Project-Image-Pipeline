package lambda;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.S3Event;

import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.model.*;

import saaf.Inspector;

import javax.imageio.ImageIO;

import java.awt.color.ColorSpace;
import java.awt.image.BufferedImage;
import java.awt.image.ColorConvertOp;
import java.io.InputStream;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.io.ByteArrayInputStream;
import java.io.IOException;

/**
 * GrayscaleHandler - Dual Mode Support
 *
 * This Lambda function converts images to grayscale and supports TWO invocation modes:
 *
 * MODE 1 - S3 Event Trigger (Original Behavior):
 *      - Triggered automatically when images are uploaded to S3 stage2/ prefix
 *      - Reads from S3, processes, writes back to S3 output/ prefix
 *      - Input type: S3Event with Records array
 *
 * MODE 2 - Direct Invocation (FaaS Runner Pipeline):
 *      - Invoked directly with image data in the payload
 *      - Used for synchronous pipelines and performance testing
 *      - Input type: Map with "image_data" (base64) or "s3_bucket"/"s3_key"
 *      - Returns processed image and metrics in response
 */
public class GrayscaleHandler implements RequestHandler<Object, HashMap<String,Object>> {

    // Amazon S3 client using Lambda execution role credentials
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

        // Extract S3 record information from the event
        com.amazonaws.services.lambda.runtime.events.models.s3.S3EventNotification.S3Entity record =
                event.getRecords().get(0).getS3();

        // Bucket name where the image resides
        String bucket = record.getBucket().getName();

        // Object key (full path inside bucket, e.g., "stage2/photo.jpg")
        String key = record.getObject().getKey();

        try {
            // ----------------------------------------------------------
            // 1. READ IMAGE FROM S3
            // ----------------------------------------------------------
            S3Object obj = s3.getObject(bucket, key);
            InputStream input = obj.getObjectContent();
            BufferedImage src = ImageIO.read(input);

            // ----------------------------------------------------------
            // 2. CONVERT IMAGE TO GRAYSCALE
            // ----------------------------------------------------------
            BufferedImage gray = toGrayscale(src);

            // ----------------------------------------------------------
            // 3. ENCODE GRAYSCALE IMAGE INTO BYTES
            // ----------------------------------------------------------
            byte[] bytes = bufferedImageToBytes(gray);

            // ----------------------------------------------------------
            // 4. WRITE PROCESSED IMAGE TO OUTPUT PREFIX
            // ----------------------------------------------------------
            String filename = key.substring(key.lastIndexOf('/') + 1);
            String newKey = "output/" + filename;

            ObjectMetadata meta = new ObjectMetadata();
            meta.setContentLength(bytes.length);
            meta.setContentType("image/jpeg");

            s3.putObject(bucket, newKey, new ByteArrayInputStream(bytes), meta);

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
            String operation = event.containsKey("operation") ? (String) event.get("operation") : "grayscale";
            inspector.addAttribute("operation", operation);

            // ----------------------------------------------------------
            // 2. CONVERT IMAGE TO GRAYSCALE
            // ----------------------------------------------------------

            BufferedImage gray = toGrayscale(src);

            // ----------------------------------------------------------
            // 3. ENCODE GRAYSCALE IMAGE BACK INTO BASE64
            // ----------------------------------------------------------

            byte[] imageBytes = bufferedImageToBytes(gray);
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

    // ---------------- Helper Methods --------------------

/**
 * Convert a BufferedImage to grayscale efficiently using ColorConvertOp.
 *
 * @param src BufferedImage input
 * @return Grayscale BufferedImage
 */
private BufferedImage toGrayscale(BufferedImage src) {
    int w = src.getWidth();
    int h = src.getHeight();

    // Create destination grayscale image
    BufferedImage gray = new BufferedImage(w, h, BufferedImage.TYPE_BYTE_GRAY);

    // Use ColorConvertOp to convert color space to grayscale
    ColorConvertOp op = new ColorConvertOp(ColorSpace.getInstance(ColorSpace.CS_GRAY), null);
    op.filter(src, gray);

    return gray;
}

    /**
     * Convert a BufferedImage to a JPEG byte array for S3 upload.
     *
     * @param img BufferedImage input
     * @return byte array containing JPEG image
     * @throws IOException
     */
    private byte[] bufferedImageToBytes(BufferedImage img) throws IOException {
        java.io.ByteArrayOutputStream baos = new java.io.ByteArrayOutputStream();
        ImageIO.write(img, "jpg", baos);
        return baos.toByteArray();
    }
}
