package lambda;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.LambdaLogger;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.model.ObjectMetadata;
import com.amazonaws.services.s3.model.PutObjectRequest;
import com.amazonaws.AmazonServiceException;

import java.io.ByteArrayInputStream;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Lambda handler that routes images to language-specific S3 buckets
 * based on the programming language specified in the input JSON payload.
 */
public class ImageRoutingHandler implements RequestHandler<Map<String, String>, Map<String, Object>> {
    
    private static final String PYTHON_BUCKET = "tcss462-term-project-group-7-python";
    private static final String JAVA_BUCKET = "tcss462-term-project-group-7-jav";
    private static final String JAVASCRIPT_BUCKET = "tcss462-term-project-group-7-js";
    private static final String INPUT_PREFIX = "input/";
    
    private final AmazonS3 s3Client;
    
    public ImageRoutingHandler() {
        this.s3Client = AmazonS3ClientBuilder.defaultClient();
    }
    
    // Constructor for testing with custom S3 client
    public ImageRoutingHandler(AmazonS3 s3Client) {
        this.s3Client = s3Client;
    }
    
    @Override
    public Map<String, Object> handleRequest(Map<String, String> input, Context context) {
        LambdaLogger logger = context.getLogger();
        
        try {
            // Validate input
            if (input == null || !input.containsKey("language") || !input.containsKey("image")) {
                logger.log("ERROR: Missing required fields in input payload");
                return createErrorResponse("Missing required fields: 'language' and 'image'");
            }
            
            String language = input.get("language");
            String imageBase64 = input.get("image");
            
            // Validate language
            String targetBucket = getBucketForLanguage(language);
            if (targetBucket == null) {
                logger.log("ERROR: Invalid language: " + language);
                return createErrorResponse("Invalid language. Must be one of: Python, Java, Javascript");
            }
            
            // Decode base64 image
            byte[] imageBytes;
            try {
                imageBytes = Base64.getDecoder().decode(imageBase64);
            } catch (IllegalArgumentException e) {
                logger.log("ERROR: Invalid base64 encoding: " + e.getMessage());
                return createErrorResponse("Invalid base64 encoding for image");
            }
            
            // Generate unique filename
            String fileName = generateFileName(language);
            
            // Upload to S3
            logger.log(String.format("Uploading image to bucket: %s, key: %s", targetBucket, fileName));
            
            ObjectMetadata metadata = new ObjectMetadata();
            metadata.setContentLength(imageBytes.length);
            metadata.setContentType("image/jpeg"); // Adjust based on your image type
            
            ByteArrayInputStream inputStream = new ByteArrayInputStream(imageBytes);
            
            PutObjectRequest putRequest = new PutObjectRequest(
                    targetBucket,
                    fileName,
                    inputStream,
                    metadata
            );
            
            s3Client.putObject(putRequest);
            
            logger.log("Successfully uploaded image to S3");
            
            return createSuccessResponse(targetBucket, fileName, imageBytes.length);
            
        } catch (AmazonServiceException e) {
            logger.log("ERROR: S3 operation failed: " + e.getMessage());
            return createErrorResponse("Failed to upload image to S3: " + e.getMessage());
            
        } catch (Exception e) {
            logger.log("ERROR: Unexpected error: " + e.getMessage());
            e.printStackTrace();
            return createErrorResponse("Internal error: " + e.getMessage());
        }
    }
    
    /**
     * Maps language to corresponding S3 bucket name
     */
    private String getBucketForLanguage(String language) {
        if (language == null) {
            return null;
        }
        
        String lowerLang = language.toLowerCase();
        
        if (lowerLang.equals("python")) {
            return PYTHON_BUCKET;
        } else if (lowerLang.equals("java")) {
            return JAVA_BUCKET;
        } else if (lowerLang.equals("javascript")) {
            return JAVASCRIPT_BUCKET;
        } else {
            return null;
        }
    }
    
    /**
     * Generates a unique filename for the image with input/ prefix
     */
    private String generateFileName(String language) {
        String timestamp = String.valueOf(System.currentTimeMillis());
        String uuid = UUID.randomUUID().toString().substring(0, 8);
        return String.format("%s%s-image-%s-%s.jpg", INPUT_PREFIX, language.toLowerCase(), timestamp, uuid);
    }
    
    /**
     * Creates a success response
     */
    private Map<String, Object> createSuccessResponse(String bucket, String fileName, int size) {
        Map<String, Object> response = new HashMap<>();
        response.put("statusCode", 200);
        response.put("success", true);
        response.put("message", "Image successfully uploaded");
        response.put("bucket", bucket);
        response.put("key", fileName);
        response.put("size", size);
        return response;
    }
    
    /**
     * Creates an error response
     */
    private Map<String, Object> createErrorResponse(String message) {
        Map<String, Object> response = new HashMap<>();
        response.put("statusCode", 400);
        response.put("success", false);
        response.put("message", message);
        return response;
    }
}