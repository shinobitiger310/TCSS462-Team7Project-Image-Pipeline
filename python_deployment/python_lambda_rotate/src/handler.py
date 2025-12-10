import boto3
import math
from io import BytesIO
from PIL import Image
from Inspector import Inspector

# Create an S3 client using the Lambda execution role credentials.
# This client is used for both reading and writing objects in S3.
s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    RotateHandler

    This Lambda function rotates images uploaded to S3 by 180 degrees and writes
    them to the "stage1/" prefix in the same bucket. It is intended to be
    triggered by S3 events (new object created) in input.

    Lambda entry point.

    S3Event event:
         - Contains information about the S3 object that triggered this Lambda.
         - Includes bucket name and object key (file path).

    Context context:
         - Provides metadata such as remaining time, request ID, and logger.
    """
    # Collect initial data.
    inspector = Inspector()
    inspector.inspectAll()

    # Extract metadata about the uploaded S3 object from the event.
    record = event['Records'][0]['s3']

    # Bucket name where the triggering image lives.
    bucket = record['bucket']['name']

    # Key is the full path inside the bucket (e.g. "input/photo.jpg").
    key = record['object']['key']

    try:
        # ----------------------------------------------------------
        # 1. READ IMAGE FROM S3
        # ----------------------------------------------------------

        # Get the object from S3 as a stream.
        obj = s3.get_object(Bucket=bucket, Key=key)
        input_stream = obj['Body'].read()

        # Convert the downloaded bytes into a PIL Image.
        src = Image.open(BytesIO(input_stream))

        # ----------------------------------------------------------
        # 2. ROTATE IMAGE BY 180 DEGREES
        # ----------------------------------------------------------

        rotated = rotate(src)

        # ----------------------------------------------------------
        # 3. ENCODE ROTATED IMAGE BACK INTO JPEG BYTES
        # ----------------------------------------------------------

        image_bytes = buffered_image_to_bytes(rotated)

        # ----------------------------------------------------------
        # 4. WRITE PROCESSED IMAGE TO NEXT STAGE IN PIPELINE
        # ----------------------------------------------------------

        # Extract just the filename from the original key.
        # Example: "input/photo.jpg" → "photo.jpg"
        filename = key[key.rfind('/') + 1:]

        # Next-stage prefix where ResizeHandler listens.
        new_key = "stage1/" + filename

        # Metadata so S3 knows the file size + content type.
        s3.put_object(
            Bucket=bucket,
            Key=new_key,
            Body=image_bytes,
            ContentLength=len(image_bytes),
            ContentType='image/jpeg'
        )

        # Create and populate a separate response object for function output. (OPTIONAL)
        # response = Response()
        # response.setValue("Bucket:" + bucketname + " filename:" + filename + " size:" + bytes.length)

        # inspector.consumeResponse(response)

        # ****************END FUNCTION IMPLEMENTATION***************************

        # Collect final information such as total runtime and cpu deltas.
        inspector.inspectAllDeltas()

        # Get the metrics as a dict
        metrics = inspector.finish()

        # Log them to CloudWatch
        context.log("INSPECTOR METRICS: " + str(metrics))

        return metrics
    except Exception as e:
        raise RuntimeError(str(e))


# ----------------------------------------------------------------------
# Helper method to rotate the image 180 degrees around its center.
#
# Why this transform?
#   - 180° rotation is equivalent to flipping horizontally + vertically.
#   - The affine transform in Java:
#         translate(w, h)
#         rotate(π radians)
#     moves the origin so the rotation happens around the image center.
#
# In Python PIL, rotate() rotates counter-clockwise by default.
# For 180°, we rotate by 180 degrees with expand=False to keep same dimensions.
# ----------------------------------------------------------------------
def rotate(src):
    """
    Rotate an image 180 degrees around its center.

    @param src PIL Image input
    @return Rotated PIL Image
    """
    # Amount to rotate in radians (180 degrees).
    rotate_amount = math.pi

    w = src.width
    h = src.height

    # Destination image with same dimensions as the original.
    # For 180° rotation, dimensions remain the same (expand=False)
    # PIL's rotate() rotates counter-clockwise, so 180° is the same regardless of direction
    dst = src.rotate(180, expand=False)

    return dst


# ----------------------------------------------------------------------
# Convert a PIL Image back into a JPEG stored in a byte array.
# This byte array can then be uploaded directly to S3.
# ----------------------------------------------------------------------
def buffered_image_to_bytes(img):
    """
    Convert a PIL Image to a JPEG byte array for S3 upload.

    @param img PIL Image input
    @return byte array containing JPEG image
    """
    baos = BytesIO()
    img.save(baos, format='JPEG')
    return baos.getvalue()
