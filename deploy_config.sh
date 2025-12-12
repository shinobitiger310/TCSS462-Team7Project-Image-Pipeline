#!/bin/bash

#
# Centralized AWS Configuration for Image Pipeline Lambda Functions
#
# This file contains all shared configuration values for deploying Lambda functions
# across Python, Java, and Node.js implementations.
#
# Usage: Source this file in deployment scripts with:
#   source ../../deploy_config.sh
#

# AWS Account Configuration
export LAMBDA_ROLE_ARN="arn:aws:iam::458329144069:role/lambda_image_pipeline_role"
export S3_BUCKET="tcss462-image-pipeline-bdiep-group7-local"
export AWS_REGION="us-west-2"

# Lambda Function Configuration
export MEMORY_SIZE="1024"
export TIMEOUT="90"

# Lambda Runtimes
export PYTHON_RUNTIME="python3.12"
export JAVA_RUNTIME="java17"
export NODEJS_RUNTIME="nodejs20.x"

# VPC Configuration (leave empty if not using VPC)
export LAMBDA_SUBNETS=""
export LAMBDA_SECURITY_GROUPS=""

# Lambda Environment Variables
export LAMBDA_ENVIRONMENT="Variables={}"

# Function Naming Convention
export PYTHON_ROTATE_FUNCTION="python_lambda_rotate"
export PYTHON_RESIZE_FUNCTION="python_lambda_resize"
export PYTHON_GREYSCALE_FUNCTION="python_lambda_greyscale"

export JAVA_ROTATE_FUNCTION="java_lambda_rotate"
export JAVA_RESIZE_FUNCTION="java_lambda_resize"
export JAVA_GREYSCALE_FUNCTION="java_lambda_grayscale"

export NODEJS_ROTATE_FUNCTION="nodejs_lambda_rotate"
export NODEJS_RESIZE_FUNCTION="nodejs_lambda_resize"
export NODEJS_GREYSCALE_FUNCTION="nodejs_lambda_greyscale"

echo "✓ Loaded centralized configuration:"
echo "  Lambda Role: $LAMBDA_ROLE_ARN"
echo "  S3 Bucket: $S3_BUCKET"
echo "  Region: $AWS_REGION"
echo "  Memory: ${MEMORY_SIZE}MB"
echo "  Timeout: ${TIMEOUT}s"
