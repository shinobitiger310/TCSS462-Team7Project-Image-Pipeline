#!/bin/bash

# Deploy Python Lambda functions using Lambda Layers for Pillow
# This avoids binary compatibility issues

set -e

echo "===== Deploying Python Lambda Functions with Lambda Layers ====="
echo ""

# Pillow Layer ARN for Python 3.12 in us-east-2
# Source: https://github.com/keithrozario/Klayers
PILLOW_LAYER_ARN="arn:aws:lambda:us-east-2:770693421928:layer:Klayers-p312-pillow:1"

# Array of function names
FUNCTIONS=("python_lambda_rotate" "python_lambda_resize" "python_lambda_greyscale")

echo "Step 1/3: Installing dependencies (boto3 only - Pillow from layer)..."
echo ""

for func in "${FUNCTIONS[@]}"; do
    echo "Installing dependencies for ${func}..."
    cd "${func}/deploy"

    # Clean existing package
    rm -rf ./package
    mkdir -p ./package

    # We don't need to install anything!
    # - boto3 is already in Lambda runtime
    # - Pillow will come from Lambda Layer
    # - SAAF Inspector is pure Python (no binaries)

    echo "  ✓ No dependencies to install (using Lambda runtime + layers)"
    cd ../..
    echo ""
done

echo ""
echo "Step 2/3: Deploying Lambda functions..."
echo ""

for func in "${FUNCTIONS[@]}"; do
    echo "Deploying ${func}..."
    cd "${func}/deploy"
    ./publish.sh
    cd ../..
    echo ""
done

echo ""
echo "Step 3/3: Adding Pillow Lambda Layer to functions..."
echo ""

for func in "${FUNCTIONS[@]}"; do
    echo "Adding Pillow layer to ${func}..."

    aws lambda update-function-configuration \
        --function-name "${func}" \
        --layers "${PILLOW_LAYER_ARN}" \
        --region us-east-2

    if [ $? -eq 0 ]; then
        echo "  ✓ Layer added successfully"
    else
        echo "  ✗ Failed to add layer"
    fi
    echo ""
done

echo ""
echo "===== Deployment Complete! ====="
echo ""
echo "Your Lambda functions now have:"
echo "  - Your handler code"
echo "  - SAAF Inspector"
echo "  - boto3 (from Lambda runtime)"
echo "  - Pillow (from Lambda Layer - Amazon Linux compatible)"
echo ""
echo "Next step: Test with ./test_python_all.sh"
