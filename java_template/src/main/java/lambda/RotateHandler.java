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
import java.util.HashMap;
import java.io.IOException;



public class RotateHandler implements RequestHandler<S3Event, HashMap<String,Object>> {

    // Create an S3 client using the Lambda execution role credentials.
    // This client is used for both reading and writing objects in S3.
    private final AmazonS3 s3 = AmazonS3ClientBuilder.defaultClient();


    /**
     * Lambda entry point.
     * 
     * S3Event event:
     *      - Contains information about the S3 object that triggered this Lambda.
     *      - Includes bucket name and object key (file path).
     *
     * Context context:
     *      - Provides metadata such as remaining time, request ID, and logger.
     */
    @Override
    public HashMap<String, Object> handleRequest(S3Event event, Context context) {
        //Collect inital data.
        Inspector inspector = new Inspector();
        inspector.inspectAll();

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

            // Pipeline tracking for CloudWatch metrics
            inspector.addAttribute("image_id", filename);
            inspector.addAttribute("pipeline_stage", "rotate");

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
            throw new RuntimeException(e);
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
