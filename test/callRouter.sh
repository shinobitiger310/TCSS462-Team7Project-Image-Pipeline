#!/bin/bash
set -e  # Exit on error

# Define the target directory and filename pattern
TARGET_DIR="./Kirmizi_Pistachio/"
FILENAME_PATTERN="*.jpg"

# Define language argument
LANGUAGE="Python"

# Find the file and store its path (-print -quit gets first match and stops)
echo "Searching for $FILENAME_PATTERN in $TARGET_DIR..."
FILE_PATH=$(find "$TARGET_DIR" -maxdepth 1 -type f -name "$FILENAME_PATTERN" -print -quit)

# Check if a file was found
if [ -z "$FILE_PATH" ]; then
    echo "Error: No file matching '$FILENAME_PATTERN' found in '$TARGET_DIR'."
    exit 1
fi

echo "✓ Found file: $FILE_PATH"

# Get file size for validation
FILE_SIZE=$(stat -f%z "$FILE_PATH" 2>/dev/null || stat -c%s "$FILE_PATH" 2>/dev/null)
echo "✓ File size: $FILE_SIZE bytes"

# Warn if file is large (Lambda payload limit is 6MB for synchronous invocations)
if [ "$FILE_SIZE" -gt 5000000 ]; then
    echo "⚠ Warning: File is large (>5MB). May exceed Lambda payload limits."
fi

# Create temporary file for payload
TEMP_PAYLOAD=$(mktemp)
TEMP_RESPONSE=$(mktemp)
trap "rm -f $TEMP_PAYLOAD $TEMP_RESPONSE" EXIT

# Create JSON payload and save to temp file
echo "Encoding image to base64..."
cat > "$TEMP_PAYLOAD" <<EOF
{
  "language": "$LANGUAGE",
  "image": "$(base64 -i "$FILE_PATH" | tr -d '\n')"
}
EOF

echo "✓ Payload created ($(stat -f%z "$TEMP_PAYLOAD" 2>/dev/null || stat -c%s "$TEMP_PAYLOAD" 2>/dev/null) bytes)"

echo ""
echo "Invoking Lambda function 'projectRunner' in us-east-2..."
echo "================================================"

# Invoke Lambda using file payload
time aws lambda invoke \
    --invocation-type RequestResponse \
    --cli-binary-format raw-in-base64-out \
    --function-name projectRunner \
    --region us-east-2 \
    --payload "file://$TEMP_PAYLOAD" \
    "$TEMP_RESPONSE" > /dev/null

echo ""
echo "JSON RESULT:"
echo "================================================"
cat "$TEMP_RESPONSE" | jq
echo ""

# Check if response indicates success
if cat "$TEMP_RESPONSE" | jq -e '.success == true' > /dev/null 2>&1; then
    echo "✓ Lambda execution successful!"
    
    # Extract bucket and key if available
    BUCKET=$(cat "$TEMP_RESPONSE" | jq -r '.bucket // empty')
    KEY=$(cat "$TEMP_RESPONSE" | jq -r '.key // empty')
    
    if [ -n "$BUCKET" ] && [ -n "$KEY" ]; then
        echo "✓ Image uploaded to: s3://$BUCKET/$KEY"
    fi
else
    echo "⚠ Lambda execution may have failed - check response above"
    exit 1
fi