import boto3
import base64
from io import BytesIO
from PIL import Image, ImageOps
from Inspector import Inspector

# Amazon S3 client using Lambda execution role credentials
s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    GrayscaleHandler - Dual Mode Support

    This Lambda function converts images to grayscale and supports TWO invocation modes:

    MODE 1 - S3 Event Trigger (Original Behavior):
         - Triggered automatically when images are uploaded to S3 stage2/ prefix
         - Reads from S3, processes, writes back to S3 output/ prefix
         - Event contains 'Records' array with S3 metadata

    MODE 2 - Direct Invocation (FaaS Runner Pipeline):
         - Invoked directly with image data in the payload
         - Used for synchronous pipelines and performance testing
         - Event contains 'image_data' (base64) or 's3_bucket'/'s3_key'
         - Returns processed image and metrics in response

    Lambda entry point - automatically detects invocation mode.
    """
    # Collect initial data.
    inspector = Inspector()
    inspector.inspectAll()

    # DETECT INVOCATION MODE
    if 'Records' in event and len(event['Records']) > 0:
        # MODE 1: S3 Event Trigger
        return handle_s3_event(event, context, inspector)
    else:
        # MODE 2: Direct Invocation (FaaS Runner)
        return handle_direct_invocation(event, context, inspector)

def handle_s3_event(event, context, inspector):
    """
    Handle S3 event-triggered invocation (original behavior).
    Reads from S3, processes, writes back to S3.
    """
    # Extract S3 record information from the event
    record = event['Records'][0]['s3']

    # Bucket name where the image resides
    bucket = record['bucket']['name']

    # Object key (full path inside bucket, e.g., "stage2/photo.jpg")
    key = record['object']['key']

    try:
        # ----------------------------------------------------------
        # 1. READ IMAGE FROM S3
        # ----------------------------------------------------------
        obj = s3.get_object(Bucket=bucket, Key=key)
        input_stream = obj['Body'].read()
        src = Image.open(BytesIO(input_stream))

        # ----------------------------------------------------------
        # 2. CONVERT IMAGE TO GRAYSCALE
        # ----------------------------------------------------------
        gray = to_grayscale(src)

        # ----------------------------------------------------------
        # 3. ENCODE GRAYSCALE IMAGE INTO BYTES
        # ----------------------------------------------------------
        image_bytes = buffered_image_to_bytes(gray)

        # ----------------------------------------------------------
        # 4. WRITE PROCESSED IMAGE TO OUTPUT PREFIX
        # ----------------------------------------------------------
        filename = key[key.rfind('/') + 1:]
        new_key = "output/" + filename

        s3.put_object(
            Bucket=bucket,
            Key=new_key,
            Body=image_bytes,
            ContentLength=len(image_bytes),
            ContentType='image/jpeg'
        )

        # ****************END FUNCTION IMPLEMENTATION***************************

        # Collect final information such as total runtime and cpu deltas.
        inspector.inspectAllDeltas()

        # Get the metrics as a dict
        metrics = inspector.finish()

        # Log them to CloudWatch
        context.log("INSPECTOR METRICS: " + str(metrics))

        return metrics

    except Exception as e:
        context.log("ERROR in S3 event handler: " + str(e))
        raise RuntimeError(str(e))

def handle_direct_invocation(event, context, inspector):
    """
    Handle direct invocation for FaaS Runner pipelines.
    Accepts image data in payload, processes it, returns result with metrics.

    Expected event format:
    {
        "image_data": "base64_encoded_image",  # Option 1: Direct base64 data
        OR
        "s3_bucket": "bucket-name",            # Option 2: S3 reference
        "s3_key": "path/to/image.jpg",

        "operation": "grayscale"               # Operation name (for logging)
    }

    Returns:
    {
        "image_data": "base64_encoded_grayscale_image",
        "operation": "grayscale",
        "success": true,
        "runtime": 123,                        # Inspector metrics
        "version": "1.0",                      # SAAF version (required by FaaS Runner)
        ... other Inspector metrics ...
    }
    """
    try:
        # ----------------------------------------------------------
        # 1. READ IMAGE FROM PAYLOAD OR S3
        # ----------------------------------------------------------

        if 'image_data' in event:
            # Option 1: Image data provided as base64 in payload
            image_b64 = event['image_data']
            image_bytes = base64.b64decode(image_b64)
            src = Image.open(BytesIO(image_bytes))
            inspector.addAttribute("input_source", "payload")

        elif 's3_bucket' in event and 's3_key' in event:
            # Option 2: S3 reference provided
            bucket = event['s3_bucket']
            key = event['s3_key']

            obj = s3.get_object(Bucket=bucket, Key=key)
            input_stream = obj['Body'].read()
            src = Image.open(BytesIO(input_stream))
            inspector.addAttribute("input_source", "s3")
            inspector.addAttribute("s3_bucket", bucket)
            inspector.addAttribute("s3_key", key)

        else:
            raise ValueError("Missing required fields: either 'image_data' or ('s3_bucket' and 's3_key')")

        # Add operation info
        operation = event.get('operation', 'grayscale')
        inspector.addAttribute("operation", operation)

        # ----------------------------------------------------------
        # 2. CONVERT IMAGE TO GRAYSCALE
        # ----------------------------------------------------------

        gray = to_grayscale(src)

        # ----------------------------------------------------------
        # 3. ENCODE GRAYSCALE IMAGE BACK INTO BASE64
        # ----------------------------------------------------------

        image_bytes = buffered_image_to_bytes(gray)
        result_b64 = base64.b64encode(image_bytes).decode('utf-8')

        # Add result info
        inspector.addAttribute("output_size", len(image_bytes))
        inspector.addAttribute("success", True)

        # ----------------------------------------------------------
        # 4. COLLECT METRICS AND RETURN RESPONSE
        # ----------------------------------------------------------

        inspector.inspectAllDeltas()
        metrics = inspector.finish()

        # Add processed image to response
        metrics['image_data'] = result_b64
        metrics['operation'] = operation

        context.log("INSPECTOR METRICS (without image_data): " + str({k: v for k, v in metrics.items() if k != 'image_data'}))

        return metrics

    except Exception as e:
        context.log("ERROR in direct invocation handler: " + str(e))

        # Return error with metrics
        inspector.addAttribute("success", False)
        inspector.addAttribute("error", str(e))
        inspector.inspectAllDeltas()
        return inspector.finish()


# ---------------- Helper Methods --------------------

def to_grayscale(src):
    """
    Convert a PIL Image to grayscale efficiently using PIL's convert method.

    @param src PIL Image input
    @return Grayscale PIL Image
    """
    w = src.width
    h = src.height

    # Create destination grayscale image
    # Convert to 'L' mode (8-bit grayscale)
    gray = src.convert('L')

    return gray


def buffered_image_to_bytes(img):
    """
    Convert a PIL Image to a JPEG byte array for S3 upload.

    @param img PIL Image input
    @return byte array containing JPEG image
    """
    baos = BytesIO()
    img.save(baos, format='JPEG')
    return baos.getvalue()
