#!/bin/bash

# cloudwatch_cleanup.sh - Delete old CloudWatch log streams

echo "=========================================="
echo "CLOUDWATCH LOGS CLEANUP"
echo "=========================================="
echo ""

LOG_GROUPS=(
    "/aws/lambda/python_lambda_rotate"
    "/aws/lambda/python_lambda_resize"
    "/aws/lambda/python_lambda_greyscale"
    "/aws/lambda/rotateJava"
    "/aws/lambda/resizeJava"
    "/aws/lambda/grayJava"
    "/aws/lambda/nodejs_lambda_rotate"
    "/aws/lambda/nodejs_lambda_resize"
    "/aws/lambda/nodejs_lambda_grayscale"
)

echo "⚠ WARNING: This will delete ALL log streams from Lambda log groups!"
echo "This cannot be undone."
echo ""
read -p "Are you sure? (type 'DELETE' to confirm): " confirm

if [ "$confirm" != "DELETE" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Starting cleanup..."

for log_group in "${LOG_GROUPS[@]}"; do
    echo ""
    echo "Processing: $log_group"
    
    # Check if log group exists
    if ! aws logs describe-log-groups \
        --log-group-name-prefix "$log_group" \
        --region us-east-2 \
        --query "logGroups[?logGroupName=='$log_group']" \
        --output text &>/dev/null; then
        echo "  ✗ Log group does not exist"
        continue
    fi
    
    # Get all log streams
    streams=$(aws logs describe-log-streams \
        --log-group-name "$log_group" \
        --region us-east-2 \
        --query 'logStreams[*].logStreamName' \
        --output text)
    
    if [ -z "$streams" ]; then
        echo "  - No log streams to delete"
        continue
    fi
    
    stream_count=$(echo "$streams" | wc -w)
    echo "  Found $stream_count log streams"
    echo "  Deleting..."
    
    # Delete each log stream
    deleted=0
    for stream in $streams; do
        aws logs delete-log-stream \
            --log-group-name "$log_group" \
            --log-stream-name "$stream" \
            --region us-east-2 2>/dev/null
        
        if [ $? -eq 0 ]; then
            ((deleted++))
        fi
    done
    
    echo "  ✓ Deleted $deleted log streams"
done

echo ""
echo "=========================================="
echo "CLOUDWATCH CLEANUP COMPLETE"
echo "=========================================="