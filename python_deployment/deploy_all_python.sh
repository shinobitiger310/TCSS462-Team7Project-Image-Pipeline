#!/bin/bash

echo "===== Deploying Python Image Pipeline Lambda Functions ====="
echo ""

# Install dependencies
echo "Step 1/2: Installing dependencies..."
echo ""

echo "Installing dependencies for python_lambda_rotate..."
cd python_lambda_rotate/deploy
./install_dependencies.sh
cd ../..

echo ""
echo "Installing dependencies for python_lambda_resize..."
cd python_lambda_resize/deploy
./install_dependencies.sh
cd ../..

echo ""
echo "Installing dependencies for python_lambda_greyscale..."
cd python_lambda_greyscale/deploy
./install_dependencies.sh
cd ../..

echo ""
echo "Step 2/2: Deploying Lambda functions..."
echo ""

# Deploy rotate
echo "===== Deploying python_lambda_rotate ====="
cd python_lambda_rotate/deploy
./publish.sh
cd ../..

echo ""

# Deploy resize
echo "===== Deploying python_lambda_resize ====="
cd python_lambda_resize/deploy
./publish.sh
cd ../..

echo ""

# Deploy greyscale
echo "===== Deploying python_lambda_greyscale ====="
cd python_lambda_greyscale/deploy
./publish.sh
cd ../..

echo ""
echo "===== DEPLOYMENT COMPLETE ====="
echo ""
echo "All three Lambda functions have been deployed:"
echo "  ✓ python_lambda_rotate"
echo "  ✓ python_lambda_resize"
echo "  ✓ python_lambda_greyscale"
echo ""
echo "Next steps:"
echo "1. Upload a test image to S3"
echo "2. Run ./test_python_all.sh to test the pipeline"
echo ""
