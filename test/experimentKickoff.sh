#!/bin/bash
# FaaS Runner for language comparison experiments.
# @version 1.0

set -e  # Exit on error

# Define the target directory and filename pattern
TARGET_DIR="./Kirmizi_Pistachio/"
FILENAME_PATTERN="*.jpg"
RESULTS_DIR="./results"

# Define language arguments
LANGUAGES=("Python" "Java")

# Create results directory
mkdir -p "$RESULTS_DIR"

# Find the file and store its path
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

# Warn if file is large
if [ "$FILE_SIZE" -gt 5000000 ]; then
    echo "⚠ Warning: File is large (>5MB). May exceed Lambda payload limits."
fi

# Create timestamp for this run
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RUN_DIR="$RESULTS_DIR/run_$TIMESTAMP"
mkdir -p "$RUN_DIR"

echo ""
echo "Results will be saved to: $RUN_DIR"
echo ""

# Loop through each language
for LANGUAGE in "${LANGUAGES[@]}"; do
    echo "================================================"
    echo "Processing language: $LANGUAGE"
    echo "================================================"
    
    # Create payload file for this language
    PAYLOAD_FILE="$RUN_DIR/${LANGUAGE}_payload.json"
    RESPONSE_FILE="$RUN_DIR/${LANGUAGE}_response.json"
    
    # Create JSON payload
    echo "Encoding image to base64..."
    cat > "$PAYLOAD_FILE" <<EOF
{
  "language": "$LANGUAGE",
  "image": "$(base64 -i "$FILE_PATH" | tr -d '\n')"
}
EOF
    
    echo "✓ Payload created: $PAYLOAD_FILE"
    echo "  Size: $(stat -f%z "$PAYLOAD_FILE" 2>/dev/null || stat -c%s "$PAYLOAD_FILE" 2>/dev/null) bytes"
    
    # Invoke using faas-runner
    echo ""
    echo "Running experiments for $LANGUAGE..."
    
    if ./faas-runner -f ./functions/routerFunction.json -e ./experiments/exampleExperiment.json --parentPayload "$PAYLOAD_FILE" -o "$RESPONSE_FILE"; then
        echo "✓ FaaS Runner completed successfully for $LANGUAGE"
        echo "✓ Response saved to: $RESPONSE_FILE"
        
        # Display response
        if [ -f "$RESPONSE_FILE" ] && [ -s "$RESPONSE_FILE" ]; then
            echo ""
            echo "Response preview:"
            head -20 "$RESPONSE_FILE"
            echo ""
        fi
    else
        echo "✗ FaaS Runner failed for $LANGUAGE"
    fi
    
    echo ""
done

echo "================================================"
echo "All experiments completed!"
echo "================================================"
echo ""
echo "Results saved in: $RUN_DIR"
echo ""
echo "Files created:"
ls -lh "$RUN_DIR"