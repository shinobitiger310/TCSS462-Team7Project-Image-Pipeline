#!/bin/bash
set -e

# Configuration
TARGET_DIR="./Kirmizi_Pistachio/"
FILENAME_PATTERN="*.jpg"
LANGUAGE="${1:-Python}"
CONCURRENCY="${2:-1}"
BATCH_SIZE="${3:-10}"

echo "=== Configuration ==="
echo "Language: $LANGUAGE"
echo "Requested Concurrency: $CONCURRENCY"
echo "Batch Size: $BATCH_SIZE"
echo ""

echo "Actual Concurrency: $CONCURRENCY"
echo ""

PREFIX="input/"

case "${LANGUAGE,,}" in
    python)
        INPUT_BUCKET="tcss462-term-project-group-7-python"
        ;;
    java)
        INPUT_BUCKET="tcss462-term-project-group-7-jav"
        ;;
    javascript)
        INPUT_BUCKET="tcss462-term-project-group-7-js"
        ;;
    *)
        echo "Error: Language must be Python, Java, or JavaScript"
        exit 1
        ;;
esac

echo "Searching for $FILENAME_PATTERN in $TARGET_DIR..."
mapfile -t FILES < <(find "$TARGET_DIR" -maxdepth 1 -type f -name "$FILENAME_PATTERN")

if [ ${#FILES[@]} -eq 0 ]; then
    echo "Error: No files matching '$FILENAME_PATTERN' found."
    exit 1
fi

echo "✓ Found ${#FILES[@]} files"
echo "✓ Target bucket: s3://${INPUT_BUCKET}/${PREFIX}"
echo ""

# Check system resources before starting
echo "System Check:"
FREE_MEM=$(free -m | awk 'NR==2{printf "%.0f", $7}')
echo "  Available Memory: ${FREE_MEM}MB"
if [ $FREE_MEM -lt 500 ]; then
    echo "  ⚠ Warning: Low memory. Consider restarting VM or reducing concurrency."
fi
echo ""

echo "Starting uploads (Ctrl+C to cancel)..."
echo "================================================"

# Trap to cleanup on exit
cleanup() {
    echo ""
    echo "Cleaning up background processes..."
    pkill -P $$ 2>/dev/null || true
    wait 2>/dev/null || true
    echo "Cleanup complete"
    exit 1
}

trap cleanup INT TERM

UPLOAD_START=$(date +%s)

# Process in small, manageable chunks
for chunk_start in $(seq 1 $CONCURRENCY $BATCH_SIZE); do
    chunk_end=$((chunk_start + CONCURRENCY - 1))
    if [ $chunk_end -gt $BATCH_SIZE ]; then
        chunk_end=$BATCH_SIZE
    fi
    
    CHUNK_SIZE=$((chunk_end - chunk_start + 1))
    echo "Processing batch: $chunk_start-$chunk_end ($CHUNK_SIZE uploads)"
    
    # Launch uploads for this chunk
    pids=()
    for i in $(seq $chunk_start $chunk_end); do
        FILE_INDEX=$(((i - 1) % ${#FILES[@]}))
        FILE_PATH="${FILES[$FILE_INDEX]}"
        TIMESTAMP=$(date +%s%N)
        S3_KEY="${PREFIX}test_${LANGUAGE,,}_${i}_${TIMESTAMP}.jpg"
        
        (
            # Try upload with timeout
            if timeout 30 aws s3 cp "$FILE_PATH" "s3://${INPUT_BUCKET}/${S3_KEY}" \
                --region us-east-2 \
                --only-show-errors &>/dev/null; then
                echo "  [$i] ✓"
            else
                echo "  [$i] ✗"
            fi
        ) &
        pids+=($!)
    done
    
    # Wait for all uploads in this chunk to complete
    for pid in "${pids[@]}"; do
        wait $pid 2>/dev/null || true
    done
    
    # Progress update
    COMPLETED=$chunk_end
    PERCENT=$((COMPLETED * 100 / BATCH_SIZE))
    echo "  Progress: $COMPLETED/$BATCH_SIZE ($PERCENT%)"
    
    # Brief pause to let VM breathe
    sleep 1
    echo ""
done

UPLOAD_END=$(date +%s)
UPLOAD_DURATION=$((UPLOAD_END - UPLOAD_START))

echo "================================================"
echo "✓ Upload batch complete!"
echo "✓ Uploaded: $BATCH_SIZE images"
echo "✓ Duration: ${UPLOAD_DURATION}s"

if [ $UPLOAD_DURATION -gt 0 ]; then
    RATE=$(echo "scale=2; $BATCH_SIZE / $UPLOAD_DURATION" | bc)
    echo "✓ Upload rate: ${RATE} images/second"
fi

echo ""
echo "Next steps:"
echo "  1. Wait 2-3 minutes for Lambda processing"
echo "  2. Query CloudWatch Logs for performance metrics"
echo "  3. Check s3://${INPUT_BUCKET}/output/ for processed images"