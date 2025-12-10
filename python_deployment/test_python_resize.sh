#!/bin/bash

# Test python_lambda_resize individually

BUCKET_NAME="tcss462-image-pipeline-bdiep-group7-local"

echo "===== Testing python_lambda_resize ====="
echo ""

# Check if stage1/ exists in S3
echo "Step 1: Checking for input file in stage1/ folder..."
aws s3 ls s3://${BUCKET_NAME}/stage1/

if [ $? -ne 0 ]; then
    echo "ERROR: No files found in stage1/ folder"
    echo "Please run test_python_rotate.sh first"
    exit 1
fi

echo "✓ Input file found in stage1/"
echo ""

# Create payload file
echo "Step 2: Creating payload..."
cat > payload_resize.json <<PAYLOAD
{
  "bucket_name": "${BUCKET_NAME}",
  "scale_percent": 150
}
PAYLOAD

# Invoke Lambda function
echo "Step 3: Invoking python_lambda_resize..."
aws lambda invoke \
  --function-name python_lambda_resize \
  --cli-binary-format raw-in-base64-out \
  --payload file://payload_resize.json \
  response_resize.json

echo ""
echo "Step 4: Response from Lambda:"
cat response_resize.json | python3 -m json.tool 2>/dev/null || cat response_resize.json
echo ""

# Check output in S3
echo "Step 5: Checking S3 for output in stage2/..."
aws s3 ls s3://${BUCKET_NAME}/stage2/

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ SUCCESS: File created in stage2/"

    # Get the filename
    FILENAME=$(aws s3 ls s3://${BUCKET_NAME}/stage2/ | awk '{print $4}' | head -1)
    
    if [ -n "$FILENAME" ]; then
        OUTPUT_FILE="stage2_${FILENAME}"
        echo ""
        echo "Step 6: Downloading result..."
        aws s3 cp s3://${BUCKET_NAME}/stage2/${FILENAME} $OUTPUT_FILE

        echo "✓ Downloaded to: $OUTPUT_FILE"
    fi
else
    echo ""
    echo "✗ ERROR: Output file not found in S3"
fi

echo ""
echo "===== Test Complete ====="

