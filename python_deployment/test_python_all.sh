#!/bin/bash

# Test the complete Python Image Pipeline
# This script uploads images from local input/ folder and runs all three Lambda functions in sequence

BUCKET_NAME="tcss462-term-project-group-7"

echo "=========================================="
echo "  Python Image Pipeline - Complete Test"
echo "=========================================="
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
echo "Step 0: Uploading images to S3 input/ folder..."
echo ""

aws s3 sync input/ s3://${BUCKET_NAME}/input/ \
    --exclude "*" \
    --include "*.jpg" \
    --include "*.jpeg" \
    --include "*.png" \
    --include "*.JPG" \
    --include "*.JPEG" \
    --include "*.PNG"

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Images uploaded successfully"
    echo ""
    echo "S3 input/ folder contents:"
    aws s3 ls s3://${BUCKET_NAME}/input/
    echo ""
else
    echo ""
    echo "✗ ERROR: Failed to upload images to S3"
    exit 1
fi

# ===== Test 1: Rotate =====
echo "=========================================="
echo "  Test 1: python_lambda_rotate (180°)"
echo "=========================================="
echo ""

cat > payload_rotate.json <<PAYLOAD
{
  "bucket_name": "${BUCKET_NAME}",
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
    echo "✓ Greyscale SUCCESS: output/ folder created"
else
    echo "✗ Greyscale FAILED"
    exit 1
fi

echo ""

# ===== Download Final Results =====
echo "=========================================="
echo "  Downloading Final Results"
echo "=========================================="
echo ""

# Create output directory for downloaded images
mkdir -p final_output

# Download all processed images from output/ folder
echo "Downloading all processed images from S3 output/ folder..."
aws s3 sync s3://${BUCKET_NAME}/output/ ./final_output/ \
    --exclude "*" \
    --include "*.jpg" \
    --include "*.jpeg" \
    --include "*.png"

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ All processed images downloaded to: ./final_output/"
    echo ""
    echo "Downloaded files:"
    ls -lh ./final_output/
fi

echo ""
echo "=========================================="
echo "  🎉 PIPELINE COMPLETE!"
echo "=========================================="
echo ""
echo "Folder structure in S3:"
echo "  input/       → Original images ($IMAGE_COUNT file(s))"
echo "  stage1/      → Rotated 180°"
echo "  stage2/      → Resized 150%"
echo "  output/      → Final greyscale images"
echo ""
echo "Local output: ./final_output/"
echo ""
