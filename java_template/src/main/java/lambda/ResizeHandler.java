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
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;

import java.io.InputStream;
import java.util.HashMap;
import java.io.ByteArrayInputStream;
import java.io.IOException;

/**
 * ResizeHandler
 * 
 * This Lambda function resizes images uploaded to S3 by 150% and writes
 * them to the "stage2/" prefix in the same bucket. It is intended to be
 * triggered by S3 events (new object created) in stage1.
 */
public class ResizeHandler implements RequestHandler<S3Event, HashMap<String,Object>> {

    // Amazon S3 client using Lambda's execution role credentials
    private final AmazonS3 s3 = AmazonS3ClientBuilder.defaultClient();

    /**
     * Lambda entry point.
     * 
     * @param event   S3Event object containing metadata about the triggering S3 object
     * @param context Context object for logging and Lambda runtime info
     * @return A string message confirming where the processed image was written
     */
    @Override
    public HashMap<String,Object> handleRequest(S3Event event, Context context) {
        //Collect inital data.
        Inspector inspector = new Inspector();
        inspector.inspectAll();

        // Extract S3 record information from the event
        com.amazonaws.services.lambda.runtime.events.models.s3.S3EventNotification.S3Entity record =
                event.getRecords().get(0).getS3();

        // Bucket name where the image lives
        String bucket = record.getBucket().getName();

        // Object key (full path inside bucket, e.g., "stage1/photo.jpg")
        String key = record.getObject().getKey();

        try {
            // ----------------------------------------------------------
            // 1. READ IMAGE FROM S3
            // ----------------------------------------------------------

            // Download the S3 object as an InputStream
            S3Object obj = s3.getObject(bucket, key);
            InputStream input = obj.getObjectContent();

            // Convert the stream into a BufferedImage for processing
            BufferedImage src = ImageIO.read(input);

            // ----------------------------------------------------------
            // 2. RESIZE IMAGE TO 150%
            // ----------------------------------------------------------

            BufferedImage resized = resize(src);

            // ----------------------------------------------------------
            // 3. ENCODE RESIZED IMAGE INTO BYTES
            // ----------------------------------------------------------

            byte[] bytes = bufferedImageToBytes(resized);

            // ----------------------------------------------------------
            // 4. WRITE PROCESSED IMAGE TO NEXT STAGE IN PIPELINE
            // ----------------------------------------------------------

            // Extract just the filename from the key (e.g., "photo.jpg")
            String filename = key.substring(key.lastIndexOf('/') + 1);

            // Pipeline tracking for CloudWatch metrics
            inspector.addAttribute("image_id", filename);
            inspector.addAttribute("pipeline_stage", "resize");

            // Next-stage prefix where the next handler listens
            String newKey = "stage2/" + filename;

            // Metadata so S3 knows the file size + content type
            ObjectMetadata meta = new ObjectMetadata();
            meta.setContentLength(bytes.length);
            meta.setContentType("image/jpeg");

            // Upload the resized image back to S3
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
            // Re-throw exceptions as RuntimeException so Lambda logs it as an error
            throw new RuntimeException(e);
        }
    }

    // ---------------- Helper Functions --------------------

    /**
     * Resize an image to 150% of its original width and height.
     *
     * @param src BufferedImage to resize
     * @return New BufferedImage resized by 150%
     */
    private BufferedImage resize(BufferedImage src) {
        double resizeFactor = 1.5;

        int origW = src.getWidth();
        int origH = src.getHeight();

        int newW = (int) (origW * resizeFactor);
        int newH = (int) (origH * resizeFactor);

        // Create a new BufferedImage for the resized image
        BufferedImage dst = new BufferedImage(newW, newH, src.getType());
        Graphics2D g = dst.createGraphics();

        // Use bilinear interpolation for smooth scaling
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION,
                           RenderingHints.VALUE_INTERPOLATION_BILINEAR);

        // Draw the original image scaled to new dimensions
        g.drawImage(src, 0, 0, newW, newH, null);
        g.dispose();

        return dst;
    }

    /**
     * Convert a BufferedImage to a byte array in JPEG format.
     *
     * @param img BufferedImage to convert
     * @return byte array of JPEG image
     * @throws IOException
     */
    private byte[] bufferedImageToBytes(BufferedImage img) throws IOException {
        java.io.ByteArrayOutputStream baos = new java.io.ByteArrayOutputStream();
        ImageIO.write(img, "jpg", baos);
        return baos.toByteArray();
    }
}
