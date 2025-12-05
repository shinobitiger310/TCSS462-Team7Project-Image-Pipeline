#!/bin/bash

# Test python_lambda_rotate individually

BUCKET_NAME="tcss462-image-pipeline-bdiep-group7-local"
INPUT_IMAGE="input_image.jpeg"

echo "===== Testing python_lambda_rotate ====="
echo ""

# Check if input image exists locally
if [ ! -f "$INPUT_IMAGE" ]; then
    echo "ERROR: $INPUT_IMAGE not found in current directory"
    echo "Please provide an input image file"
    exit 1
fi

echo "Using image: $INPUT_IMAGE"
echo ""

# Upload input image to S3
echo "Step 1: Uploading $INPUT_IMAGE to S3..."
aws s3 cp $INPUT_IMAGE s3://${BUCKET_NAME}/
echo ""

# Create payload file
echo "Step 2: Creating payload..."
cat > payload_rotate.json <<PAYLOAD
{
  "bucket_name": "${BUCKET_NAME}",
  "input_key": "${INPUT_IMAGE}",
  "rotation_degrees": 180
}
PAYLOAD

# Invoke Lambda function
echo "Step 3: Invoking python_lambda_rotate..."
aws lambda invoke \
  --function-name python_lambda_rotate \
  --cli-binary-format raw-in-base64-out \
  --payload file://payload_rotate.json \
  response_rotate.json

echo ""
echo "Step 4: Response from Lambda:"
cat response_rotate.json | python3 -m json.tool 2>/dev/null || cat response_rotate.json
echo ""

# Check output in S3
echo "Step 5: Checking S3 for output in stage1/..."
aws s3 ls s3://${BUCKET_NAME}/stage1/

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ SUCCESS: stage1/${INPUT_IMAGE} created in S3"

    # Download output
    OUTPUT_FILE="stage1_${INPUT_IMAGE}"
    echo ""
    echo "Step 6: Downloading result..."
    aws s3 cp s3://${BUCKET_NAME}/stage1/${INPUT_IMAGE} $OUTPUT_FILE

    echo "✓ Downloaded to: $OUTPUT_FILE"
else
    echo ""
    echo "✗ ERROR: Output file not found in S3"
fi

echo ""
echo "===== Test Complete ====="
