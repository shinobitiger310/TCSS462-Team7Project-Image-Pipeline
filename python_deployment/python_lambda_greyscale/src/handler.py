import json
import boto3
import os
from io import BytesIO
from PIL import Image
from Inspector import Inspector

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    Lambda function to convert an image to greyscale.
    Reads from S3 stage2/{filename}, converts to greyscale, and writes to S3 as output/{filename}

    Event parameters (Manual invocation):
    - bucket_name: S3 bucket name (required)
    - input_key: Input file to convert (default: auto-detects stage2/*)
    - greyscale_mode: Greyscale conversion mode - 'L' for standard or '1' for binary (default: 'L')

    Event parameters (S3 trigger):
    - Records[0].s3.bucket.name: S3 bucket name (automatically provided)
    - Records[0].s3.object.key: S3 object key (automatically provided)
    - Environment variable GREYSCALE_MODE: 'L' for standard or '1' for binary (default: 'L')
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
            greyscale_mode = os.environ.get('GREYSCALE_MODE', 'L')
            inspector.addAttribute("trigger_type", "s3_event")
        else:
            # Manual invocation format
            bucket_name = event.get('bucket_name')
            greyscale_mode = event.get('greyscale_mode', 'L')
            inspector.addAttribute("trigger_type", "manual_invoke")

            if not bucket_name:
                raise ValueError("bucket_name is required in the event")

            # Auto-detect input file in stage2/ folder if not provided
            input_key = event.get('input_key')
            if not input_key:
                # List files in stage2/ folder
                response = s3_client.list_objects_v2(Bucket=bucket_name, Prefix='stage2/')
                if 'Contents' in response and len(response['Contents']) > 0:
                    # Get the first non-empty image file in stage2/
                    for obj in response['Contents']:
                        key = obj['Key']
                        size = obj['Size']

                        # Skip if it's just the folder itself or empty
                        if key == 'stage2/' or size == 0:
                            continue

                        # Check if it's an image file
                        if key.lower().endswith(('.jpg', '.jpeg', '.png')):
                            input_key = key
                            break

                    if not input_key:
                        raise ValueError("Could not find image file (.jpg, .jpeg, .png) in stage2/ folder")
                else:
                    raise ValueError("Could not find input file in stage2/ folder")

        # Extract filename from input_key
        filename = os.path.basename(input_key)
        file_extension = os.path.splitext(filename)[1]

        inspector.addAttribute("input_key", input_key)
        inspector.addAttribute("filename", filename)
        inspector.addAttribute("greyscale_mode", greyscale_mode)

        # Download image from S3
        inspector.addAttribute("step", "downloading_image")
        response = s3_client.get_object(Bucket=bucket_name, Key=input_key)
        image_data = response['Body'].read()

        original_size = len(image_data)
        inspector.addAttribute("input_size_bytes", original_size)

        # Open and convert to greyscale
        inspector.addAttribute("step", "converting_to_greyscale")
        image = Image.open(BytesIO(image_data))

        original_dimensions = image.size
        original_mode = image.mode
        inspector.addAttribute("original_width", original_dimensions[0])
        inspector.addAttribute("original_height", original_dimensions[1])
        inspector.addAttribute("original_mode", original_mode)

        # Convert to greyscale
        greyscale_image = image.convert(greyscale_mode)

        greyscale_dimensions = greyscale_image.size
        inspector.addAttribute("greyscale_width", greyscale_dimensions[0])
        inspector.addAttribute("greyscale_height", greyscale_dimensions[1])
        inspector.addAttribute("greyscale_mode_result", greyscale_image.mode)

        # Save greyscale image to BytesIO
        output_buffer = BytesIO()

        # Determine format based on extension
        image_format = 'JPEG'
        if file_extension.lower() in ['.png']:
            image_format = 'PNG'
        elif file_extension.lower() in ['.jpg', '.jpeg']:
            image_format = 'JPEG'

        greyscale_image.save(output_buffer, format=image_format)
        output_buffer.seek(0)

        output_size = len(output_buffer.getvalue())
        inspector.addAttribute("output_size_bytes", output_size)

        # Upload to S3 in output folder with original filename
        output_key = f"output/{filename}"
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
        inspector.addAttribute("message", f"Successfully converted {input_key} to greyscale as {output_key}")

    except Exception as e:
        inspector.addAttribute("error", str(e))
        inspector.addAttribute("message", f"Error converting image to greyscale: {str(e)}")

    # Collect final metrics
    inspector.inspectAllDeltas()
    result = inspector.finish()

    # Print metrics to CloudWatch logs
    print(json.dumps(result, indent=2))

    return result
