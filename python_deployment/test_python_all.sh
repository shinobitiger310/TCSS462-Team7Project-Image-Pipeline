#!/bin/bash

# Test the complete Python Image Pipeline
# This script runs all three Lambda functions in sequence

BUCKET_NAME="tcss462-image-pipeline-bdiep-group7-local"
INPUT_IMAGE="input_image.jpeg"

echo "=========================================="
echo "  Python Image Pipeline - Complete Test"
echo "=========================================="
echo ""

# Check if input image exists locally
if [ ! -f "$INPUT_IMAGE" ]; then
    echo "ERROR: $INPUT_IMAGE not found in current directory"
    echo "Please provide an input image file"
    exit 1
fi

# Upload input image to S3
echo "Step 0: Uploading $INPUT_IMAGE to S3..."
aws s3 cp $INPUT_IMAGE s3://${BUCKET_NAME}/
echo ""

# ===== Test 1: Rotate =====
echo "=========================================="
echo "  Test 1: python_lambda_rotate (180°)"
echo "=========================================="
echo ""

cat > payload_rotate.json <<PAYLOAD
{
  "bucket_name": "${BUCKET_NAME}",
  "input_key": "${INPUT_IMAGE}",
  "rotation_degrees": 180
}
PAYLOAD

echo "Invoking python_lambda_rotate..."
aws lambda invoke \
  --function-name python_lambda_rotate \
  --cli-binary-format raw-in-base64-out \
  --payload file://payload_rotate.json \
  response_rotate.json

echo ""
cat response_rotate.json | python3 -m json.tool 2>/dev/null || cat response_rotate.json
echo ""

# Check if stage1/ was created
aws s3 ls s3://${BUCKET_NAME}/stage1/
if [ $? -eq 0 ]; then
    echo "✓ Rotate SUCCESS: stage1/${INPUT_IMAGE} created"
else
    echo "✗ Rotate FAILED"
    exit 1
fi

echo ""

# ===== Test 2: Resize =====
echo "=========================================="
echo "  Test 2: python_lambda_resize (150%)"
echo "=========================================="
echo ""

cat > payload_resize.json <<PAYLOAD
{
  "bucket_name": "${BUCKET_NAME}",
  "scale_percent": 150
}
PAYLOAD

echo "Invoking python_lambda_resize..."
aws lambda invoke \
  --function-name python_lambda_resize \
  --cli-binary-format raw-in-base64-out \
  --payload file://payload_resize.json \
  response_resize.json

echo ""
cat response_resize.json | python3 -m json.tool 2>/dev/null || cat response_resize.json
echo ""

# Check if stage2/ was created
aws s3 ls s3://${BUCKET_NAME}/stage2/
if [ $? -eq 0 ]; then
    echo "✓ Resize SUCCESS: stage2/${INPUT_IMAGE} created"
else
    echo "✗ Resize FAILED"
    exit 1
fi

echo ""

# ===== Test 3: Greyscale =====
echo "=========================================="
echo "  Test 3: python_lambda_greyscale"
echo "=========================================="
echo ""

cat > payload_greyscale.json <<PAYLOAD
{
  "bucket_name": "${BUCKET_NAME}",
  "greyscale_mode": "L"
}
PAYLOAD

echo "Invoking python_lambda_greyscale..."
aws lambda invoke \
  --function-name python_lambda_greyscale \
  --cli-binary-format raw-in-base64-out \
  --payload file://payload_greyscale.json \
  response_greyscale.json

echo ""
cat response_greyscale.json | python3 -m json.tool 2>/dev/null || cat response_greyscale.json
echo ""

# Check if output/ was created
aws s3 ls s3://${BUCKET_NAME}/output/
if [ $? -eq 0 ]; then
    echo "✓ Greyscale SUCCESS: output/${INPUT_IMAGE} created"
else
    echo "✗ Greyscale FAILED"
    exit 1
fi

echo ""

# ===== Download Final Result =====
echo "=========================================="
echo "  Downloading Final Result"
echo "=========================================="
echo ""

OUTPUT_FILE="final_output_python.jpeg"
aws s3 cp s3://${BUCKET_NAME}/output/${INPUT_IMAGE} $OUTPUT_FILE

echo "✓ Downloaded to: $OUTPUT_FILE"

echo ""
echo "=========================================="
echo "  🎉 PIPELINE COMPLETE!"
echo "=========================================="
echo ""
echo "Folder structure in S3:"
echo "  ${INPUT_IMAGE} (original)"
echo "  stage1/${INPUT_IMAGE} (rotated 180°)"
echo "  stage2/${INPUT_IMAGE} (resized 150%)"
echo "  output/${INPUT_IMAGE} (greyscale)"
echo ""
echo "Final output: $OUTPUT_FILE"
echo ""
