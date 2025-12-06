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
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.HashMap;

/**
 * GrayscaleHandler
 *
 * This Lambda function converts images uploaded to S3 into grayscale
 * and writes them to the "output/" prefix in the same bucket. It is intended
 * to be triggered by S3 events (new object created) in stage2.
 */
public class GrayscaleHandler implements RequestHandler<S3Event, HashMap<String,Object>> {

    // Amazon S3 client using Lambda execution role credentials
    private final AmazonS3 s3 = AmazonS3ClientBuilder.defaultClient();

    /**
     * Lambda entry point
     *
     * @param event   S3Event object containing metadata about the triggering S3 object
     * @param context Context object for logging and Lambda runtime info
     * @return A HashMap containing optional metrics (if Inspector is added) or simple message
     */
    @Override
    public HashMap<String,Object> handleRequest(S3Event event, Context context) {
        //Collect inital data.
        Inspector inspector = new Inspector();
        inspector.inspectAll();

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
            // Re-throw exceptions as RuntimeException for Lambda to log
            throw new RuntimeException(e);
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
