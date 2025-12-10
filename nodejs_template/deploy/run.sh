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

# Get bucket paths
BASE_BUCKET=$(cat $CONFIG | jq -r '.buckets.base')
INPUT_BUCKET=$(cat $CONFIG | jq -r '.buckets.input')
STAGE1_BUCKET=$(cat $CONFIG | jq -r '.buckets.stage1')
STAGE2_BUCKET=$(cat $CONFIG | jq -r '.buckets.stage2')
OUTPUT_BUCKET=$(cat $CONFIG | jq -r '.buckets.output')

# Get function names
ROTATE_FUNC=$(cat $CONFIG | jq -r '.functions.rotate.functionName')
ZOOM_FUNC=$(cat $CONFIG | jq -r '.functions.zoom.functionName')
GREYSCALE_FUNC=$(cat $CONFIG | jq -r '.functions.greyscale.functionName')

echo "===== Image Processing Pipeline ====="
echo ""
echo "✓ Found file: $IMAGE_PATH"
echo "✓ File size: $FILE_SIZE bytes"
echo ""
echo "Base bucket: $BASE_BUCKET"
echo "Pipeline: input/ → stage1/ → stage2/ → output/"
echo ""

echo "Uploading $FILENAME to S3..."
echo "================================================"
aws s3 cp "$IMAGE_PATH" "s3://$INPUT_BUCKET/$FILENAME"

echo "✓ Upload complete: s3://$INPUT_BUCKET/$FILENAME"
echo ""

echo "Waiting for pipeline to complete..."
sleep 20

echo ""
echo "===== Pipeline Status ====="
echo "================================================"

# Check each stage
echo ""
echo "----- Stage 1: Rotate -----"
STAGE1_EXISTS=$(aws s3 ls "s3://$STAGE1_BUCKET/$FILENAME" 2>/dev/null)
if [[ -n "$STAGE1_EXISTS" ]]; then
    echo "✓ Rotate complete: s3://$STAGE1_BUCKET/$FILENAME"
else
    echo "✗ Rotate failed or still processing"
fi

echo ""
echo "----- Stage 2: Resize -----"
STAGE2_EXISTS=$(aws s3 ls "s3://$STAGE2_BUCKET/$FILENAME" 2>/dev/null)
if [[ -n "$STAGE2_EXISTS" ]]; then
    echo "✓ Resize complete: s3://$STAGE2_BUCKET/$FILENAME"
else
    echo "✗ Resize failed or still processing"
fi

echo ""
echo "----- Stage 3: Greyscale -----"
OUTPUT_EXISTS=$(aws s3 ls "s3://$OUTPUT_BUCKET/$FILENAME" 2>/dev/null)
if [[ -n "$OUTPUT_EXISTS" ]]; then
    echo "✓ Greyscale complete: s3://$OUTPUT_BUCKET/$FILENAME"
else
    echo "✗ Greyscale failed or still processing"
fi

echo ""
echo "===== SAAF Output ====="
echo "================================================"

echo ""
echo "----- Rotate -----"
ROTATE_OUTPUT=$(aws logs tail /aws/lambda/$ROTATE_FUNC --since 2m --format short 2>/dev/null | grep -o '{.*}' | tail -1)
if [[ -n "$ROTATE_OUTPUT" ]]; then
    echo "$ROTATE_OUTPUT" | jq .
else
    echo "⚠ No output found - check CloudWatch logs"
fi

echo ""
echo "----- Resize -----"
ZOOM_OUTPUT=$(aws logs tail /aws/lambda/$ZOOM_FUNC --since 2m --format short 2>/dev/null | grep -o '{.*}' | tail -1)
if [[ -n "$ZOOM_OUTPUT" ]]; then
    echo "$ZOOM_OUTPUT" | jq .
else
    echo "⚠ No output found - check CloudWatch logs"
fi

echo ""
echo "----- Greyscale -----"
GREYSCALE_OUTPUT=$(aws logs tail /aws/lambda/$GREYSCALE_FUNC --since 2m --format short 2>/dev/null | grep -o '{.*}' | tail -1)
if [[ -n "$GREYSCALE_OUTPUT" ]]; then
    echo "$GREYSCALE_OUTPUT" | jq .
else
    echo "⚠ No output found - check CloudWatch logs"
fi

echo ""
echo "===== Pipeline Complete ====="
echo "================================================"
echo ""

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