#!/bin/bash

# Test python_lambda_rotate individually
# Uploads images from local input/ folder to S3

BUCKET_NAME="tcss462-term-project-group-7"

echo "===== Testing python_lambda_rotate ====="
echo ""

# Check if local input/ folder exists
if [ ! -d "input" ]; then
    echo "ERROR: Local input/ folder not found"
    echo "Please create an input/ folder and add your image files (.jpg, .jpeg, .png)"
    exit 1
fi

# Check if input folder has any image files
IMAGE_COUNT=$(find input/ -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) 2>/dev/null | wc -l)

if [ "$IMAGE_COUNT" -eq 0 ]; then
    echo "ERROR: input/ folder exists but contains no image files"
    echo "Please add image files (.jpg, .jpeg, .png) to the input/ folder"
    exit 1
fi

# Upload images from local input/ folder to S3
echo "Found $IMAGE_COUNT image file(s) in local input/ folder"
echo "Step 1: Uploading images to S3 input/ folder..."
echo ""

aws s3 sync input/ s3://${BUCKET_NAME}/input/ \
    --exclude "*" \
    --include "*.jpg" \
    --include "*.jpeg" \
    --include "*.png" \
    --include "*.JPG" \
    --include "*.JPEG" \
    --include "*.PNG"

echo ""
echo "✓ Images uploaded successfully"
echo ""

# Create payload file
echo "Step 2: Creating payload..."
cat > payload_rotate.json <<PAYLOAD
{
  "bucket_name": "${BUCKET_NAME}",
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
