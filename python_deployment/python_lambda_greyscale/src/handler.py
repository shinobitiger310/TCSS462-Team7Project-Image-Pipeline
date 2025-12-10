import boto3
from io import BytesIO
from PIL import Image, ImageOps
from Inspector import Inspector

# Amazon S3 client using Lambda execution role credentials
s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    GrayscaleHandler

    This Lambda function converts images uploaded to S3 into grayscale
    and writes them to the "output/" prefix in the same bucket. It is intended
    to be triggered by S3 events (new object created) in stage2.

    Lambda entry point

    @param event   S3Event object containing metadata about the triggering S3 object
    @param context Context object for logging and Lambda runtime info
    @return A dict containing optional metrics (if Inspector is added) or simple message
    """
    # Collect initial data.
    inspector = Inspector()
    inspector.inspectAll()

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
        # Re-throw exceptions as RuntimeError for Lambda to log
        raise RuntimeError(str(e))


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
