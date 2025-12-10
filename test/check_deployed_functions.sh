#!/bin/bash

# Check which Lambda functions are deployed
# This helps verify function names match before running experiments

echo "=========================================="
echo "  Checking Deployed Lambda Functions"
echo "=========================================="
echo ""

EXPECTED_FUNCTIONS=(
    "python_lambda_rotate"
    "python_lambda_resize"
    "python_lambda_greyscale"
    "java_lambda_rotate"
    "java_lambda_resize"
    "java_lambda_grayscale"
    "nodejs_lambda_rotate"
    "nodejs_lambda_resize"
    "nodejs_lambda_greyscale"
)

echo "Getting list of deployed Lambda functions..."
DEPLOYED=$(aws lambda list-functions --query 'Functions[].FunctionName' --output text)

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to list Lambda functions. Check AWS credentials."
    exit 1
fi

echo ""
echo "Checking for expected functions:"
echo ""

FOUND=0
MISSING=0

for func in "${EXPECTED_FUNCTIONS[@]}"; do
    if echo "$DEPLOYED" | grep -q "$func"; then
        echo "  ✓ $func"
        FOUND=$((FOUND + 1))
    else
        echo "  ✗ $func (NOT DEPLOYED)"
        MISSING=$((MISSING + 1))
    fi
done

echo ""
echo "=========================================="
echo "  Summary:"
echo "    Found: $FOUND"
echo "    Missing: $MISSING"
echo "=========================================="
echo ""

if [ $MISSING -gt 0 ]; then
    echo "⚠ Warning: Some functions are not deployed."
    echo ""
    echo "To deploy missing functions:"
    echo "  Python: cd python_deployment && ./deploy_all_python.sh"
    echo "  Java: cd java_template/deploy && ./publish.sh"
    echo "  Node.js: cd nodejs_template/deploy && ./publish.sh"
    echo ""
fi

echo "All deployed Lambda functions:"
echo "$DEPLOYED" | tr '\t' '\n' | sort
echo ""
