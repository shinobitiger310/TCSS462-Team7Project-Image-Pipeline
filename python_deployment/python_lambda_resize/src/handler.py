import json
import boto3
import os
from io import BytesIO
from PIL import Image
from Inspector import Inspector

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    Lambda function to resize an image.
    Reads from S3 stage1/{filename}, resizes it, and writes to S3 as stage2/{filename}

    Event parameters (Manual invocation):
    - bucket_name: S3 bucket name (required)
    - scale_percent: Scale image by percentage (default: 150). If width/height not specified, uses this.
    - width: Target width in pixels (optional, overrides scale_percent)
    - height: Target height in pixels (optional, overrides scale_percent)
    - maintain_aspect_ratio: If True, maintains aspect ratio when using width/height (default: False)
    - input_key: Input file to resize (default: auto-detects stage1/*)

    Event parameters (S3 trigger):
    - Records[0].s3.bucket.name: S3 bucket name (automatically provided)
    - Records[0].s3.object.key: S3 object key (automatically provided)
    - Environment variables: SCALE_PERCENT (default: 150), WIDTH, HEIGHT
    """
    # Initialize Inspector for performance monitoring
    inspector = Inspector()
    inspector.inspectAll()

    try:
        # Check if this is an S3 trigger event or manual invocation
        if 'Records' in event and len(event['Records']) > 0:
            # S3 trigger event format
            s3_record = event['Records'][0]['s3']
            bucket_name = s3_record['bucket']['name']
            input_key = s3_record['object']['key']
            scale_percent = int(os.environ.get('SCALE_PERCENT', 150))
            target_width = int(os.environ.get('WIDTH')) if os.environ.get('WIDTH') else None
            target_height = int(os.environ.get('HEIGHT')) if os.environ.get('HEIGHT') else None
            maintain_aspect_ratio = os.environ.get('MAINTAIN_ASPECT_RATIO', 'false').lower() == 'true'
            inspector.addAttribute("trigger_type", "s3_event")
        else:
            # Manual invocation format
            bucket_name = event.get('bucket_name')
            scale_percent = event.get('scale_percent', 150)
            target_width = event.get('width')
            target_height = event.get('height')
            maintain_aspect_ratio = event.get('maintain_aspect_ratio', False)
            inspector.addAttribute("trigger_type", "manual_invoke")

            if not bucket_name:
                raise ValueError("bucket_name is required in the event")

            # Auto-detect input file in stage1/ folder if not provided
            input_key = event.get('input_key')
            if not input_key:
                # List files in stage1/ folder
                response = s3_client.list_objects_v2(Bucket=bucket_name, Prefix='stage1/')
                if 'Contents' in response and len(response['Contents']) > 0:
                    # Get the first non-empty image file in stage1/
                    for obj in response['Contents']:
                        key = obj['Key']
                        size = obj['Size']

                        # Skip if it's just the folder itself or empty
                        if key == 'stage1/' or size == 0:
                            continue

                        # Check if it's an image file
                        if key.lower().endswith(('.jpg', '.jpeg', '.png')):
                            input_key = key
                            break

                    if not input_key:
                        raise ValueError("Could not find image file (.jpg, .jpeg, .png) in stage1/ folder")
                else:
                    raise ValueError("Could not find input file in stage1/ folder")

        # Extract filename from input_key
        filename = os.path.basename(input_key)
        file_extension = os.path.splitext(filename)[1]

        inspector.addAttribute("input_key", input_key)
        inspector.addAttribute("filename", filename)

        # Pipeline tracking for CloudWatch metrics
        inspector.addAttribute("image_id", filename)
        inspector.addAttribute("pipeline_stage", "resize")

        # Download image from S3
        inspector.addAttribute("step", "downloading_image")
        response = s3_client.get_object(Bucket=bucket_name, Key=input_key)
        image_data = response['Body'].read()

        original_size = len(image_data)
        inspector.addAttribute("input_size_bytes", original_size)

        # Open and resize image
        inspector.addAttribute("step", "resizing_image")
        image = Image.open(BytesIO(image_data))

        original_dimensions = image.size
        inspector.addAttribute("original_width", original_dimensions[0])
        inspector.addAttribute("original_height", original_dimensions[1])

        # Calculate target dimensions
        # If width and height are not specified, use scale_percent
        if target_width is None and target_height is None:
            target_width = int(original_dimensions[0] * scale_percent / 100)
            target_height = int(original_dimensions[1] * scale_percent / 100)
            inspector.addAttribute("scale_percent", scale_percent)
            inspector.addAttribute("resize_mode", "percentage")
        else:
            inspector.addAttribute("resize_mode", "absolute")

        inspector.addAttribute("target_width", target_width)
        inspector.addAttribute("target_height", target_height)
        inspector.addAttribute("maintain_aspect_ratio", maintain_aspect_ratio)

        # Resize based on parameters
        if maintain_aspect_ratio and (event.get('width') or event.get('height')):
            # Calculate aspect ratio preserving dimensions (only when explicit width/height given)
            image.thumbnail((target_width, target_height), Image.Resampling.LANCZOS)
            resized_image = image
        else:
            # Resize to exact dimensions
            resized_image = image.resize((target_width, target_height), Image.Resampling.LANCZOS)

        resized_dimensions = resized_image.size
        inspector.addAttribute("resized_width", resized_dimensions[0])
        inspector.addAttribute("resized_height", resized_dimensions[1])

        # Save resized image to BytesIO
        output_buffer = BytesIO()

        # Determine format based on extension
        image_format = 'JPEG'
        if file_extension.lower() in ['.png']:
            image_format = 'PNG'
        elif file_extension.lower() in ['.jpg', '.jpeg']:
            image_format = 'JPEG'

        resized_image.save(output_buffer, format=image_format)
        output_buffer.seek(0)

        output_size = len(output_buffer.getvalue())
        inspector.addAttribute("output_size_bytes", output_size)

        # Upload to S3 in stage2 folder with original filename
        output_key = f"stage2/{filename}"
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
        inspector.addAttribute("message", f"Successfully resized {input_key} to {resized_dimensions[0]}x{resized_dimensions[1]} as {output_key}")

    except Exception as e:
        inspector.addAttribute("error", str(e))
        inspector.addAttribute("message", f"Error resizing image: {str(e)}")

    # Collect final metrics
    inspector.inspectAllDeltas()
    result = inspector.finish()

    # Print metrics to CloudWatch logs
    print(json.dumps(result, indent=2))

    return result
