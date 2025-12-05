#!/bin/bash

# Get bucket name from config file
BUCKET_NAME=$(grep -o '"bucket_name"[[:space:]]*:[[:space:]]*"[^"]*"' \
  python_lambda_rotate/deploy/config.json | \
  grep -o '"[^"]*"$' | tr -d '"')

if [ -z "$BUCKET_NAME" ]; then
    echo "ERROR: Could not read bucket_name from config.json"
    exit 1
fi

echo "===== Deploying Python Image Pipeline Lambda Functions ====="
echo ""

# Step 0: Upload images from local input/ folder to S3
echo "Step 0/3: Uploading images from local input/ folder to S3..."
echo ""

# Check if local input/ folder exists
if [ ! -d "input" ]; then
    echo "ERROR: Local input/ folder not found"
    echo "Please create an input/ folder and add your image files (.jpg, .jpeg, .png)"
    exit 1
fi

# Check if input folder has any image files
IMAGE_COUNT=$(find input/ -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) 2>/dev/null | wc -l)

if [ "$IMAGE_COUNT" -eq 0 ]; then
    echo "ERROR: input/ folder exists but contains no image files"
    echo "Please add image files (.jpg, .jpeg, .png) to the input/ folder"
    exit 1
fi

echo "Found $IMAGE_COUNT image file(s) in local input/ folder"
echo "Syncing to s3://${BUCKET_NAME}/input/..."
echo ""

# Sync images to S3 (only uploads new/modified files)
aws s3 sync input/ s3://${BUCKET_NAME}/input/ \
    --exclude "*" \
    --include "*.jpg" \
    --include "*.jpeg" \
    --include "*.png" \
    --include "*.JPG" \
    --include "*.JPEG" \
    --include "*.PNG"

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Images synced successfully to S3"
    echo ""
    echo "S3 input/ folder contents:"
    aws s3 ls s3://${BUCKET_NAME}/input/
    echo ""
else
    echo ""
    echo "✗ ERROR: Failed to sync images to S3"
    exit 1
fi

# Install dependencies
echo "Step 1/3: Installing dependencies..."
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
echo "Step 2/3: Deploying Lambda functions..."
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
echo "Images uploaded to S3 input/ folder: $IMAGE_COUNT file(s)"
echo ""
echo "Next steps:"
echo "  Run ./test_python_all.sh to test the pipeline"
echo ""
