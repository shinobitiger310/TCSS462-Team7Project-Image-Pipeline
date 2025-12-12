#!/bin/bash

# increase_lambda_timeout.sh - Increase timeout and memory for Lambda functions

echo "=========================================="
echo "INCREASE LAMBDA TIMEOUT & MEMORY"
echo "=========================================="
echo ""

# Configuration
TIMEOUT=30  # seconds (max is 900 for Lambda)
MEMORY_PYTHON=512
MEMORY_JAVA=512
MEMORY_JS=512

echo "Settings:"
echo "  Timeout: $TIMEOUT seconds"
echo "  Python Memory: $MEMORY_PYTHON MB"
echo "  Java Memory: $MEMORY_JAVA MB"
echo "  JavaScript Memory: $MEMORY_JS MB"
echo ""
read -p "Apply these settings? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Updating Python functions..."

aws lambda update-function-configuration \
    --function-name python_lambda_rotate \
    --timeout $TIMEOUT \
    --memory-size $MEMORY_PYTHON \
    --region us-east-2
echo "  ✓ python_lambda_rotate"

aws lambda update-function-configuration \
    --function-name python_lambda_resize \
    --timeout $TIMEOUT \
    --memory-size $MEMORY_PYTHON \
    --region us-east-2
echo "  ✓ python_lambda_resize"

aws lambda update-function-configuration \
    --function-name python_lambda_greyscale \
    --timeout $TIMEOUT \
    --memory-size $MEMORY_PYTHON \
    --region us-east-2
echo "  ✓ python_lambda_greyscale"

echo ""
echo "Updating Java functions..."

aws lambda update-function-configuration \
    --function-name rotateJava \
    --timeout $TIMEOUT \
    --memory-size $MEMORY_JAVA \
    --region us-east-2
echo "  ✓ rotateJava"

aws lambda update-function-configuration \
    --function-name resizeJava \
    --timeout $TIMEOUT \
    --memory-size $MEMORY_JAVA \
    --region us-east-2
echo "  ✓ resizeJava"

aws lambda update-function-configuration \
    --function-name grayJava \
    --timeout $TIMEOUT \
    --memory-size $MEMORY_JAVA \
    --region us-east-2
echo "  ✓ grayJava"

echo ""
echo "Updating JavaScript functions..."

aws lambda update-function-configuration \
    --function-name nodejs_lambda_rotate \
    --timeout $TIMEOUT \
    --memory-size $MEMORY_JS \
    --region us-east-2
echo "  ✓ nodejs_lambda_rotate"

aws lambda update-function-configuration \
    --function-name nodejs_lambda_resize \
    --timeout $TIMEOUT \
    --memory-size $MEMORY_JS \
    --region us-east-2
echo "  ✓ nodejs_lambda_resize"

aws lambda update-function-configuration \
    --function-name nodejs_lambda_grayscale \
    --timeout $TIMEOUT \
    --memory-size $MEMORY_JS \
    --region us-east-2
echo "  ✓ nodejs_lambda_grayscale"

echo ""
echo "=========================================="
echo "UPDATE COMPLETE"
echo "=========================================="
echo ""
echo "Verifying new settings..."
echo ""

echo "Python functions:"
aws lambda get-function-configuration --function-name python_lambda_rotate --region us-east-2 | jq '{Function: .FunctionName, Timeout, MemorySize}'

echo ""
echo "Java functions:"
aws lambda get-function-configuration --function-name rotateJava --region us-east-2 | jq '{Function: .FunctionName, Timeout, MemorySize}'

echo ""
echo "JavaScript functions:"
aws lambda get-function-configuration --function-name nodejs_lambda_rotate --region us-east-2 | jq '{Function: .FunctionName, Timeout, MemorySize}'

echo ""
echo "All functions updated successfully!"