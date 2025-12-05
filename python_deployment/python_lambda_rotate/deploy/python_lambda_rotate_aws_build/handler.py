import json
import boto3
import os
from io import BytesIO
from PIL import Image
from Inspector import Inspector

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    Lambda function to rotate an image.
    Reads from S3 input/{filename}, rotates by specified degrees, and writes to S3 as stage1/{filename}

    Event parameters:
    - bucket_name: S3 bucket name (required)
    - input_key: Input file name (default: auto-detects input/*)
    - rotation_degrees: Degrees to rotate (default: 180). Positive = counter-clockwise, Negative = clockwise
    """
    # Initialize Inspector for performance monitoring
    inspector = Inspector()
    inspector.inspectAll()

    try:
        # Get parameters from event
        bucket_name = event.get('bucket_name')
        rotation_degrees = event.get('rotation_degrees', 180)  # Default 180 degrees

        if not bucket_name:
            raise ValueError("bucket_name is required in the event")

        # Auto-detect input file in input/ folder
        input_key = event.get('input_key')
        if not input_key:
            # List files in input/ folder
            response = s3_client.list_objects_v2(Bucket=bucket_name, Prefix='input/')
            if 'Contents' in response and len(response['Contents']) > 0:
                # Get the first image file in input/
                for obj in response['Contents']:
                    key = obj['Key']
                    size = obj['Size']

                    # Skip if it's just the folder itself or empty
                    if key == 'input/' or size == 0:
                        continue

                    # Check if it's an image file
                    if key.lower().endswith(('.jpg', '.jpeg', '.png')):
                        input_key = key
                        break

                if not input_key:
                    raise ValueError("Could not find image file (.jpg, .jpeg, .png) in input/ folder")
            else:
                raise ValueError("Could not find input file in input/ folder")

        # Extract filename from input_key (remove any path prefix)
        filename = os.path.basename(input_key)
        file_extension = os.path.splitext(filename)[1]  # e.g., '.jpeg', '.jpg', '.png'
        if not file_extension:
            file_extension = '.jpeg'  # default
            filename = filename + file_extension

        inspector.addAttribute("input_key", input_key)
        inspector.addAttribute("filename", filename)
        inspector.addAttribute("rotation_degrees", rotation_degrees)

        # Download image from S3
        inspector.addAttribute("step", "downloading_image")
        response = s3_client.get_object(Bucket=bucket_name, Key=input_key)
        image_data = response['Body'].read()

        original_size = len(image_data)
        inspector.addAttribute("input_size_bytes", original_size)

        # Open and rotate image
        inspector.addAttribute("step", "rotating_image")
        image = Image.open(BytesIO(image_data))

        original_dimensions = image.size
        inspector.addAttribute("original_width", original_dimensions[0])
        inspector.addAttribute("original_height", original_dimensions[1])

        # Rotate by specified degrees (expand=True ensures no cropping)
        rotated_image = image.rotate(rotation_degrees, expand=True)

        rotated_dimensions = rotated_image.size
        inspector.addAttribute("rotated_width", rotated_dimensions[0])
        inspector.addAttribute("rotated_height", rotated_dimensions[1])

        # Save rotated image to BytesIO
        output_buffer = BytesIO()

        # Determine format based on extension
        image_format = 'JPEG'
        if file_extension.lower() in ['.png']:
            image_format = 'PNG'
        elif file_extension.lower() in ['.jpg', '.jpeg']:
            image_format = 'JPEG'

        rotated_image.save(output_buffer, format=image_format)
        output_buffer.seek(0)

        output_size = len(output_buffer.getvalue())
        inspector.addAttribute("output_size_bytes", output_size)

        # Upload to S3 in stage1 folder with original filename
        output_key = f"stage1/{filename}"
        inspector.addAttribute("step", "uploading_image")
        s3_client.put_object(
            Bucket=bucket_name,
            Key=output_key,
            Body=output_buffer.getvalue(),
            ContentType=f'image/{image_format.lower()}'
        )

        inspector.addAttribute("output_key", output_key)
        inspector.addAttribute("bucket_name", bucket_name)
        inspector.addAttribute("image_format", image_format)
        inspector.addAttribute("message", f"Successfully rotated {input_key} by {rotation_degrees} degrees to {output_key}")

    except Exception as e:
        inspector.addAttribute("error", str(e))
        inspector.addAttribute("message", f"Error rotating image: {str(e)}")

    # Collect final metrics
    inspector.inspectAllDeltas()
    return inspector.finish()
