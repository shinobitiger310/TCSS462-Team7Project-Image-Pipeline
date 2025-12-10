#!/bin/bash

# Test python_lambda_greyscale individually

BUCKET_NAME="tcss462-image-pipeline-bdiep-group7-local"

echo "===== Testing python_lambda_greyscale ====="
echo ""

# Check if stage2/ exists in S3
echo "Step 1: Checking for input file in stage2/ folder..."
aws s3 ls s3://${BUCKET_NAME}/stage2/

if [ $? -ne 0 ]; then
    echo "ERROR: No files found in stage2/ folder"
    echo "Please run test_python_resize.sh first"
    exit 1
fi

echo "✓ Input file found in stage2/"
echo ""

# Create payload file
echo "Step 2: Creating payload..."
cat > payload_greyscale.json <<PAYLOAD
{
  "bucket_name": "${BUCKET_NAME}",
  "greyscale_mode": "L"
}
PAYLOAD

# Invoke Lambda function
echo "Step 3: Invoking python_lambda_greyscale..."
aws lambda invoke \
  --function-name python_lambda_greyscale \
  --cli-binary-format raw-in-base64-out \
  --payload file://payload_greyscale.json \
  response_greyscale.json

echo ""
echo "Step 4: Response from Lambda:"
cat response_greyscale.json | python3 -m json.tool 2>/dev/null || cat response_greyscale.json
echo ""

# Check output in S3
echo "Step 5: Checking S3 for output in output/ folder..."
aws s3 ls s3://${BUCKET_NAME}/output/

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ SUCCESS: File created in output/"

    # Get the filename
    FILENAME=$(aws s3 ls s3://${BUCKET_NAME}/output/ | awk '{print $4}' | head -1)
    
    if [ -n "$FILENAME" ]; then
        OUTPUT_FILE="final_output_${FILENAME}"
        echo ""
        echo "Step 6: Downloading final result..."
        aws s3 cp s3://${BUCKET_NAME}/output/${FILENAME} $OUTPUT_FILE

        echo "✓ Downloaded to: $OUTPUT_FILE"
        echo ""
        echo "🎉 PIPELINE COMPLETE! Check $OUTPUT_FILE"
    fi
else
    echo ""
    echo "✗ ERROR: Output file not found in S3"
fi

echo ""
echo "===== Test Complete ====="

