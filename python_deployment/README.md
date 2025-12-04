# Python Lambda Image Processing Pipeline

A serverless image processing pipeline built with AWS Lambda that performs sequential image transformations: rotation, resizing, and greyscale conversion.

## Project Overview

This project implements an image processing pipeline using AWS Lambda functions written in Python. The pipeline processes images through three stages:

1. **Rotate** - Rotates images by a specified angle (default: 180°)
2. **Resize** - Scales images by percentage or specific dimensions (default: 150%)
3. **Greyscale** - Converts images to greyscale

Each Lambda function reads from and writes to an S3 bucket, creating a sequential processing pipeline.

## Architecture

```
S3 Bucket (input_image.jpeg)
    ↓
Lambda: python_lambda_rotate → stage1/input_image.jpeg
    ↓
Lambda: python_lambda_resize → stage2/input_image.jpeg
    ↓
Lambda: python_lambda_greyscale → output/input_image.jpeg (final)
```

## Directory Contents

### Deployment Scripts
- **`deploy_all_python.sh`** - Master deployment script
  - Installs Pillow dependencies for each function
  - Packages and uploads to AWS Lambda
  - Configures function settings

### Testing Scripts
- **`test_python_all.sh`** - Tests complete image processing pipeline
  - Uploads test image to S3
  - Runs all three Lambda functions in sequence
  - Downloads and displays final output
- **`test_python_rotate.sh`** - Tests only the rotate Lambda function
- **`test_python_resize.sh`** - Tests only the resize Lambda function
- **`test_python_greyscale.sh`** - Tests only the greyscale Lambda function

### Setup Scripts
- **`install_python312.sh`** - Installs Python 3.12 from source
  - Required for local development
  - Matches Lambda runtime version
  - Takes 10-15 minutes to complete

### Documentation
- **`PYTHON_SETUP_GUIDE.md`** - Initial setup instructions (AWS config, IAM roles, S3)
- **`PYTHON_DEPLOYMENT_GUIDE.md`** - Detailed step-by-step deployment guide
- **`LAMBDA_LAYER_SETUP.md`** - Alternative deployment using Lambda layers

### Test Data
- **`input_image.jpeg`** - Sample input image
- **`final_output_python.jpeg`** - Sample output after pipeline processing
- **`payload_*.json`** - Test input payloads (auto-generated)
- **`response_*.json`** - Lambda function responses with SAAF metrics (auto-generated)
- **`deployall.log`** - Deployment log
- **`testall.log`** - Test execution log

## Prerequisites

### System Requirements
- **OS**: Ubuntu 20.04 or later
- **Python**: Python 3.12 (installation script provided)
- **AWS CLI**: Configured with appropriate credentials
- **Tools**: bash, zip, unzip, jq

### AWS Requirements
- AWS Account with appropriate permissions
- IAM Role for Lambda with:
  - S3 read/write access
  - Lambda execution permissions
  - CloudWatch logs permissions
- S3 bucket for storing images

## Quick Start

### 1. Install Python 3.12 (First Time Only)

```bash
chmod +x install_python312.sh
./install_python312.sh
```

This will:
- Install build dependencies
- Download Python 3.12.0 source
- Compile and install Python 3.12
- Takes approximately 10-15 minutes

### 2. Configure AWS

Update the `config.json` in each Lambda function's deploy directory:

```bash
# Edit these files with your AWS details:
../python_lambda_rotate/deploy/config.json
../python_lambda_resize/deploy/config.json
../python_lambda_greyscale/deploy/config.json
```

Required configuration:
```json
{
  "lambdaRoleARN": "arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_ROLE",
  "test": {
    "bucket_name": "your-s3-bucket-name",
    "input_key": "input_image.jpeg"
  }
}
```

### 3. Deploy Lambda Functions

```bash
chmod +x deploy_all_python.sh
./deploy_all_python.sh
```

This script will:
1. Install Python dependencies (Pillow) for each function
2. Create deployment packages (~35MB each)
3. Upload to AWS Lambda
4. Configure memory (512MB), timeout (900s), and runtime settings

### 4. Test the Pipeline

```bash
chmod +x test_python_all.sh
./test_python_all.sh
```

This will:
1. Upload `input_image.jpeg` to S3
2. Run rotate → resize → greyscale pipeline
3. Download final output as `final_output_python.jpeg`

## Usage

### Deploy All Functions

```bash
./deploy_all_python.sh
```

### Test Complete Pipeline

```bash
./test_python_all.sh
```

### Test Individual Functions

```bash
# Test rotate only
./test_python_rotate.sh

# Test resize only
./test_python_resize.sh

# Test greyscale only
./test_python_greyscale.sh
```

### Custom Parameters

#### Rotate with custom angle:
```bash
aws lambda invoke \
  --function-name python_lambda_rotate \
  --cli-binary-format raw-in-base64-out \
  --payload '{"bucket_name":"your-bucket","input_key":"input_image.jpeg","rotation_degrees":90}' \
  response.json
```

#### Resize with specific dimensions:
```bash
aws lambda invoke \
  --function-name python_lambda_resize \
  --cli-binary-format raw-in-base64-out \
  --payload '{"bucket_name":"your-bucket","width":1024,"height":768}' \
  response.json
```

#### Resize with scale percentage:
```bash
aws lambda invoke \
  --function-name python_lambda_resize \
  --cli-binary-format raw-in-base64-out \
  --payload '{"bucket_name":"your-bucket","scale_percent":200}' \
  response.json
```

## Lambda Function Details

### python_lambda_rotate
- **Runtime**: Python 3.12
- **Memory**: 512 MB
- **Timeout**: 900 seconds
- **Input**: Root bucket / `input_image.jpeg`
- **Output**: `stage1/input_image.jpeg`
- **Default Rotation**: 180 degrees
- **Location**: `../python_lambda_rotate/`

### python_lambda_resize
- **Runtime**: Python 3.12
- **Memory**: 512 MB
- **Timeout**: 900 seconds
- **Input**: `stage1/input_image.jpeg`
- **Output**: `stage2/input_image.jpeg`
- **Default Scale**: 150%
- **Location**: `../python_lambda_resize/`

### python_lambda_greyscale
- **Runtime**: Python 3.12
- **Memory**: 512 MB
- **Timeout**: 900 seconds
- **Input**: `stage2/input_image.jpeg`
- **Output**: `output/input_image.jpeg`
- **Conversion Mode**: L (Luminance/Greyscale)
- **Location**: `../python_lambda_greyscale/`

## Monitoring and Debugging

### View CloudWatch Logs

```bash
# Rotate function logs
aws logs tail /aws/lambda/python_lambda_rotate --follow

# Resize function logs
aws logs tail /aws/lambda/python_lambda_resize --follow

# Greyscale function logs
aws logs tail /aws/lambda/python_lambda_greyscale --follow
```

### Check Function Status

```bash
aws lambda list-functions \
  --query 'Functions[?contains(FunctionName, `python_lambda`)].[FunctionName,Runtime,LastModified]' \
  --output table
```

### View S3 Bucket Contents

```bash
aws s3 ls s3://your-bucket-name/
aws s3 ls s3://your-bucket-name/stage1/
aws s3 ls s3://your-bucket-name/stage2/
aws s3 ls s3://your-bucket-name/output/
```

## Performance Metrics (SAAF Inspector)

Each Lambda function includes SAAF (Serverless Application Analytics Framework) Inspector, which collects:
- **Execution time** - Total runtime in milliseconds
- **Memory usage** - Actual memory used vs allocated
- **Cold start vs warm start** - Container reuse detection
- **CPU metrics** - User/system CPU time, CPU utilization
- **Network latency** - S3 upload/download times
- **Custom metrics** - Image dimensions, file sizes, processing details

Metrics are returned in the Lambda response JSON (`response_*.json` files).

Example metrics from a successful run:
```json
{
  "runtime": 587,
  "userRuntime": 555,
  "recommendedMemory": 128,
  "input_size_bytes": 157026,
  "output_size_bytes": 134176,
  "original_width": 1536,
  "original_height": 1023
}
```

## Troubleshooting

### Common Issues

**Issue**: "No module named 'PIL'"
- **Cause**: Pillow not installed or wrong Python version used
- **Solution**: Re-run `install_dependencies.sh` in the Lambda function's deploy directory
```bash
cd ../python_lambda_rotate/deploy
./install_dependencies.sh
```

**Issue**: "Could not find input file" in Lambda
- **Cause**: Previous Lambda in pipeline didn't complete or file in wrong location
- **Solution**: Check S3 bucket for expected file
```bash
aws s3 ls s3://your-bucket-name/stage1/
aws s3 ls s3://your-bucket-name/stage2/
```

**Issue**: Lambda timeout
- **Cause**: Image too large or insufficient memory
- **Solution**: Increase timeout or memory in `config.json`
```json
{
  "memorySetting": "1024",
  "timeout": "900"
}
```

**Issue**: "Invalid base64" error during deployment test
- **Cause**: Payload format issue in publish.sh (non-critical)
- **Solution**: Ignore - function is deployed correctly. Use test scripts instead.

**Issue**: Python 3.12 not found
- **Cause**: Python 3.12 not installed or not in PATH
- **Solution**: Run `install_python312.sh` or verify installation
```bash
python3.12 --version
which python3.12
```

**Issue**: Line ending errors (bad interpreter: /bin/bash^M)
- **Cause**: Windows CRLF line endings
- **Solution**: Fix line endings
```bash
sed -i 's/\r$//' *.sh
```

### Deployment Failures

```bash
# Check deployment log
cat deployall.log

# Verify AWS credentials
aws sts get-caller-identity

# Check IAM role exists
aws iam get-role --role-name lambda_image_pipeline_role

# Verify S3 bucket exists
aws s3 ls s3://your-bucket-name/
```

### Test Failures

```bash
# Check test log
cat testall.log

# View Lambda function configuration
aws lambda get-function-configuration --function-name python_lambda_rotate

# Test Lambda function directly
aws lambda invoke \
  --function-name python_lambda_rotate \
  --cli-binary-format raw-in-base64-out \
  --payload '{"bucket_name":"your-bucket","input_key":"input_image.jpeg"}' \
  test_response.json
cat test_response.json | python3 -m json.tool
```

## Cleanup

To remove all deployed resources:

```bash
# Delete Lambda functions
aws lambda delete-function --function-name python_lambda_rotate
aws lambda delete-function --function-name python_lambda_resize
aws lambda delete-function --function-name python_lambda_greyscale

# Delete S3 bucket contents
aws s3 rm s3://your-bucket-name/ --recursive

# Delete S3 bucket
aws s3 rb s3://your-bucket-name

# Optionally delete IAM role (detach policies first)
aws iam detach-role-policy --role-name lambda_image_pipeline_role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam detach-role-policy --role-name lambda_image_pipeline_role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
aws iam delete-role --role-name lambda_image_pipeline_role
```

## Technology Stack

- **Language**: Python 3.12
- **Cloud Provider**: AWS Lambda
- **Storage**: Amazon S3
- **Image Processing**: Pillow (PIL) 12.0.0
- **Metrics**: SAAF Inspector
- **Dependencies**: boto3 (AWS SDK for Python)

## Project Structure

```
../python_lambda_rotate/          # Rotate Lambda function
├── deploy/
│   ├── config.json            # Function configuration
│   ├── publish.sh             # Deploy script
│   └── install_dependencies.sh # Install Pillow
└── src/
    ├── handler.py             # Image rotation logic
    ├── lambda_function.py     # Lambda handler
    └── Inspector.py           # SAAF metrics

../python_lambda_resize/           # Resize Lambda function
└── (same structure as rotate)

../python_lambda_greyscale/        # Greyscale Lambda function
└── (same structure as rotate)
```

## Best Practices

1. **Version Control**: Commit deployment and test logs to track history
2. **Testing**: Always test after deployment with `test_python_all.sh`
3. **Monitoring**: Check CloudWatch logs regularly for errors
4. **Cleanup**: Remove old deployment packages to save space
5. **Backups**: Keep copies of working deployment packages
6. **Security**: Never commit AWS credentials or IAM role ARNs to public repos

## Additional Resources

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [Pillow (PIL) Documentation](https://pillow.readthedocs.io/)
- [Boto3 Documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)
- [SAAF Framework](https://github.com/wlloyduw/SAAF)

## Team

TCSS 460 - Team 7
Serverless Image Processing Pipeline
University of Washington Tacoma

## License

This project is for educational purposes as part of TCSS 460 coursework.
