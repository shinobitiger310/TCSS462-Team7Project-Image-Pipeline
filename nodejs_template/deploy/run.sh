#!/bin/bash
set -e

cd "$(dirname "$0")"

CONFIG="./config.json"

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed"
    exit 1
fi

if [[ -z $1 ]]; then
    echo "Usage: ./run.sh <path_to_image>"
    exit 1
fi

IMAGE_PATH=$1

if [[ ! -f "$IMAGE_PATH" ]]; then
    echo "Error: File not found: $IMAGE_PATH"
    exit 1
fi

FILENAME=$(basename "$IMAGE_PATH")
FILE_SIZE=$(stat -f%z "$IMAGE_PATH" 2>/dev/null || stat -c%s "$IMAGE_PATH" 2>/dev/null)

INPUT_BUCKET=$(cat $CONFIG | jq -r '.buckets.input')
OUTPUT_BUCKET=$(cat $CONFIG | jq -r '.buckets.output')

ROTATE_FUNC=$(cat $CONFIG | jq -r '.functions.rotate.functionName')
ZOOM_FUNC=$(cat $CONFIG | jq -r '.functions.zoom.functionName')
GREYSCALE_FUNC=$(cat $CONFIG | jq -r '.functions.greyscale.functionName')

if [[ "$INPUT_BUCKET" == "YOUR-INPUT-BUCKET-NAME" ]]; then
    echo "Error: Please edit deploy/config.json with your bucket names"
    exit 1
fi

echo "===== Image Processing Pipeline ====="
echo ""
echo "✓ Found file: $IMAGE_PATH"
echo "✓ File size: $FILE_SIZE bytes"
echo ""
echo "Input bucket: $INPUT_BUCKET"
echo "Output bucket: $OUTPUT_BUCKET"
echo ""

echo "Uploading $FILENAME to S3..."
echo "================================================"
aws s3 cp "$IMAGE_PATH" "s3://$INPUT_BUCKET/$FILENAME"

echo "✓ Upload complete: s3://$INPUT_BUCKET/$FILENAME"
echo ""

echo "Waiting for pipeline to complete..."
sleep 20

echo ""
echo "===== SAAF Output ====="
echo "================================================"

echo ""
echo "----- Rotate -----"
ROTATE_OUTPUT=$(aws logs tail /aws/lambda/$ROTATE_FUNC --since 1m --format short 2>/dev/null | grep -o '{.*}' | tail -1)
if [[ -n "$ROTATE_OUTPUT" ]]; then
    echo "$ROTATE_OUTPUT" | jq .
    echo "✓ Rotate function completed"
else
    echo "⚠ No output found - check CloudWatch logs"
fi

echo ""
echo "----- Zoom -----"
ZOOM_OUTPUT=$(aws logs tail /aws/lambda/$ZOOM_FUNC --since 1m --format short 2>/dev/null | grep -o '{.*}' | tail -1)
if [[ -n "$ZOOM_OUTPUT" ]]; then
    echo "$ZOOM_OUTPUT" | jq .
    echo "✓ Zoom function completed"
else
    echo "⚠ No output found - check CloudWatch logs"
fi

echo ""
echo "----- Greyscale -----"
GREYSCALE_OUTPUT=$(aws logs tail /aws/lambda/$GREYSCALE_FUNC --since 1m --format short 2>/dev/null | grep -o '{.*}' | tail -1)
if [[ -n "$GREYSCALE_OUTPUT" ]]; then
    echo "$GREYSCALE_OUTPUT" | jq .
    echo "✓ Greyscale function completed"
else
    echo "⚠ No output found - check CloudWatch logs"
fi

echo ""
echo "===== Pipeline Complete ====="
echo "================================================"
echo ""

echo "Checking output bucket..."
OUTPUT_EXISTS=$(aws s3 ls "s3://$OUTPUT_BUCKET/$FILENAME" 2>/dev/null)

if [[ -n "$OUTPUT_EXISTS" ]]; then
    echo "✓ Output image ready: s3://$OUTPUT_BUCKET/$FILENAME"
    echo ""
    echo "Download with:"
    echo "  aws s3 cp s3://$OUTPUT_BUCKET/$FILENAME ./"
else
    echo "⚠ Output not found yet - pipeline may still be processing"
    echo ""
    echo "Check manually:"
    echo "  aws s3 ls s3://$OUTPUT_BUCKET/"
fi