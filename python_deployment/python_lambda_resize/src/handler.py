import boto3
from io import BytesIO
from PIL import Image
from Inspector import Inspector

# Amazon S3 client using Lambda's execution role credentials
s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    ResizeHandler

    This Lambda function resizes images uploaded to S3 by 150% and writes
    them to the "stage2/" prefix in the same bucket. It is intended to be
    triggered by S3 events (new object created) in stage1.

    Lambda entry point.

    @param event   S3Event object containing metadata about the triggering S3 object
    @param context Context object for logging and Lambda runtime info
    @return A dict message confirming where the processed image was written
    """
    # Collect initial data.
    inspector = Inspector()
    inspector.inspectAll()

    # Extract S3 record information from the event
    record = event['Records'][0]['s3']

    # Bucket name where the image lives
    bucket = record['bucket']['name']

    # Object key (full path inside bucket, e.g., "stage1/photo.jpg")
    key = record['object']['key']

    try:
        # ----------------------------------------------------------
        # 1. READ IMAGE FROM S3
        # ----------------------------------------------------------

        # Download the S3 object as an InputStream
        obj = s3.get_object(Bucket=bucket, Key=key)
        input_stream = obj['Body'].read()

        # Convert the stream into a PIL Image for processing
        src = Image.open(BytesIO(input_stream))

        # ----------------------------------------------------------
        # 2. RESIZE IMAGE TO 150%
        # ----------------------------------------------------------

        resized = resize(src)

        # ----------------------------------------------------------
        # 3. ENCODE RESIZED IMAGE INTO BYTES
        # ----------------------------------------------------------

        image_bytes = buffered_image_to_bytes(resized)

        # ----------------------------------------------------------
        # 4. WRITE PROCESSED IMAGE TO NEXT STAGE IN PIPELINE
        # ----------------------------------------------------------

        # Extract just the filename from the key (e.g., "photo.jpg")
        filename = key[key.rfind('/') + 1:]

        # Next-stage prefix where the next handler listens
        new_key = "stage2/" + filename

        # Metadata so S3 knows the file size + content type
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
        # Re-throw exceptions as RuntimeError so Lambda logs it as an error
        raise RuntimeError(str(e))


# ---------------- Helper Functions --------------------

def resize(src):
    """
    Resize an image to 150% of its original width and height.

    @param src PIL Image to resize
    @return New PIL Image resized by 150%
    """
    resize_factor = 1.5

    orig_w = src.width
    orig_h = src.height

    new_w = int(orig_w * resize_factor)
    new_h = int(orig_h * resize_factor)

    # Create a new PIL Image for the resized image
    # Use BILINEAR resampling for smooth scaling (equivalent to Java's bilinear interpolation)
    dst = src.resize((new_w, new_h), Image.Resampling.BILINEAR)

    return dst


def buffered_image_to_bytes(img):
    """
    Convert a PIL Image to a byte array in JPEG format.

    @param img PIL Image to convert
    @return byte array of JPEG image
    """
    baos = BytesIO()
    img.save(baos, format='JPEG')
    return baos.getvalue()
