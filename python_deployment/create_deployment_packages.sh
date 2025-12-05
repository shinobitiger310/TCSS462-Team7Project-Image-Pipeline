#!/bin/bash

echo "===== Creating Lambda Deployment Packages ====="
echo ""
echo "This script creates ZIP files that you can manually upload to AWS Lambda"
echo ""

# Clean up old deployment packages
rm -f python_lambda_rotate.zip python_lambda_resize.zip python_lambda_greyscale.zip

# Function to create deployment package
create_package() {
    local lambda_name=$1
    echo "Creating deployment package for ${lambda_name}..."

    cd "${lambda_name}"

    # Install dependencies if not already installed
    if [ ! -d "deploy/package" ]; then
        echo "  Installing dependencies first..."
        cd deploy
        ./install_dependencies.sh
        cd ..
    fi

    # Create the deployment package
    echo "  Packaging ${lambda_name}.zip..."
    cd deploy

    # Copy source files to package directory
    cp ../src/*.py ./package/

    # Copy Lambda handler from platforms/aws
    cp ../platforms/aws/*.py ./package/

    # Create ZIP file
    cd package
    zip -r "../../../${lambda_name}.zip" . > /dev/null 2>&1
    cd ..

    # Clean up source files from package
    rm -f ./package/*.py

    cd ../..

    echo "  ✓ Created ${lambda_name}.zip"
    echo ""
}

# Create packages for all three Lambda functions
create_package "python_lambda_rotate"
create_package "python_lambda_resize"
create_package "python_lambda_greyscale"

echo "===== Deployment Packages Created ====="
echo ""
echo "ZIP files created:"
ls -lh python_lambda_*.zip
echo ""
echo "You can now upload these ZIP files manually to AWS Lambda:"
echo "  1. Go to AWS Lambda Console"
echo "  2. Create a new function or update existing function"
echo "  3. Upload the corresponding ZIP file"
echo ""
echo "Function configurations:"
echo "  - Runtime: Python 3.12"
echo "  - Handler: lambda_function.lambda_handler"
echo "  - Memory: 512 MB"
echo "  - Timeout: 900 seconds (15 minutes)"
echo "  - IAM Role: arn:aws:iam::458329144069:role/lambda_image_pipeline_role"
echo ""