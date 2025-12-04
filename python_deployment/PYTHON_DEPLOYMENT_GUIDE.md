# Deployment Guide - Python Image Pipeline Lambda Functions

Your configuration is ready! Follow these steps to deploy your Lambda functions to AWS.

## Prerequisites Check

Make sure you have:
- ✅ AWS CLI configured (`aws configure`)
- ✅ Python 3.x installed
- ✅ pip installed
- ✅ jq installed (for JSON parsing)
- ✅ Updated all config.json files with your IAM Role ARN and S3 bucket

Verify AWS CLI is working:
```bash
aws sts get-caller-identity
```

---

## Deployment Steps

### Step 1: Install Dependencies for Each Lambda Function

Each Lambda function needs Python packages (boto3 and Pillow) bundled with it.

#### For python_lambda_rotate:
```bash
cd python_lambda_rotate/deploy
./install_dependencies.sh
cd ../..
```

#### For python_lambda_resize:
```bash
cd python_lambda_resize/deploy
./install_dependencies.sh
cd ../..
```

#### For python_lambda_greyscale:
```bash
cd python_lambda_greyscale/deploy
./install_dependencies.sh
cd ../..
```

**Note for Windows users**: If you get permission errors, try:
```bash
# Make scripts executable
chmod +x python_lambda_rotate/deploy/install_dependencies.sh
chmod +x python_lambda_resize/deploy/install_dependencies.sh
chmod +x python_lambda_greyscale/deploy/install_dependencies.sh

# Or run with bash explicitly
bash python_lambda_rotate/deploy/install_dependencies.sh
```

---

### Step 2: Deploy Lambda Functions

Now deploy each function using the `publish.sh` script:

#### Deploy python_lambda_rotate:
```bash
cd python_lambda_rotate/deploy
./publish.sh
cd ../..
```

**What this does:**
- Packages your code with dependencies
- Creates/updates the Lambda function `python_lambda_rotate`
- Tests it with the payload from config.json
- Shows you the response

#### Deploy python_lambda_resize:
```bash
cd python_lambda_resize/deploy
./publish.sh
cd ../..
```

#### Deploy python_lambda_greyscale:
```bash
cd python_lambda_greyscale/deploy
./publish.sh
cd ../..
```

---

### Step 3: Verify Deployment

Check that all functions were created:

```bash
aws lambda list-functions --query 'Functions[?contains(FunctionName, `python_lambda`)].[FunctionName,Runtime,Handler]' --output table
```

You should see:
```
----------------------------------------
|           ListFunctions              |
+------------------------+-------------+
| python_lambda_rotate   | python3.14  |
| python_lambda_resize   | python3.14  |
| python_lambda_greyscale| python3.14  |
+------------------------+-------------+
```

---

## Quick Deploy All Script (Optional)

Create a single script to deploy all functions at once:

### deploy_all.sh
```bash
#!/bin/bash

echo "===== Deploying All Lambda Functions ====="
echo ""

# Install dependencies
echo "Step 1: Installing dependencies..."
cd python_lambda_rotate/deploy && ./install_dependencies.sh && cd ../..
cd python_lambda_resize/deploy && ./install_dependencies.sh && cd ../..
cd python_lambda_greyscale/deploy && ./install_dependencies.sh && cd ../..

echo ""
echo "Step 2: Deploying functions..."

# Deploy rotate
echo ""
echo "===== Deploying python_lambda_rotate ====="
cd python_lambda_rotate/deploy && ./publish.sh && cd ../..

# Deploy resize
echo ""
echo "===== Deploying python_lambda_resize ====="
cd python_lambda_resize/deploy && ./publish.sh && cd ../..

# Deploy greyscale
echo ""
echo "===== Deploying python_lambda_greyscale ====="
cd python_lambda_greyscale/deploy && ./publish.sh && cd ../..

echo ""
echo "===== All functions deployed! ====="
```

Save this as `deploy_all.sh`, then run:
```bash
chmod +x deploy_all.sh
./deploy_all.sh
```

---

## Testing Your Deployed Functions

### 1. Upload a test image to S3:
```bash
# Upload an image file to your S3 bucket
aws s3 cp input_image.jpeg s3://tcss462-image-pipeline-bdiep-group7-local/

# Verify it was uploaded
aws s3 ls s3://tcss462-image-pipeline-bdiep-group7-local/
```

### 2. Test python_lambda_rotate:
```bash
aws lambda invoke \
  --function-name python_lambda_rotate \
  --payload '{"bucket_name":"tcss462-image-pipeline-bdiep-group7-local","input_key":"input_image.jpeg"}' \
  response_rotate.json

# View the response
cat response_rotate.json | jq .
```

### 3. Check if state1_python was created:
```bash
aws s3 ls s3://tcss462-image-pipeline-bdiep-group7-local/
```

You should see `state1_python.jpeg` (or .jpg or .png depending on your input)

### 4. Test python_lambda_resize:
```bash
aws lambda invoke \
  --function-name python_lambda_resize \
  --payload '{"bucket_name":"tcss462-image-pipeline-bdiep-group7-local"}' \
  response_resize.json

cat response_resize.json | jq .
```

### 5. Check if state2_python was created:
```bash
aws s3 ls s3://tcss462-image-pipeline-bdiep-group7-local/
```

### 6. Test python_lambda_greyscale:
```bash
aws lambda invoke \
  --function-name python_lambda_greyscale \
  --payload '{"bucket_name":"tcss462-image-pipeline-bdiep-group7-local"}' \
  response_greyscale.json

cat response_greyscale.json | jq .
```

### 7. Check final output:
```bash
aws s3 ls s3://tcss462-image-pipeline-bdiep-group7-local/

# Download the final processed image
aws s3 cp s3://tcss462-image-pipeline-bdiep-group7-local/state3_python.jpeg final_output.jpeg
```

---

## Running the Complete Pipeline

```bash
# 1. Upload input image
aws s3 cp input_image.jpeg s3://tcss462-image-pipeline-bdiep-group7-local/

# 2. Run rotate (180 degrees by default)
aws lambda invoke --function-name python_lambda_rotate \
  --payload '{"bucket_name":"tcss462-image-pipeline-bdiep-group7-local","input_key":"input_image.jpeg"}' \
  response1.json

# 3. Run resize (150% scale by default)
aws lambda invoke --function-name python_lambda_resize \
  --payload '{"bucket_name":"tcss462-image-pipeline-bdiep-group7-local"}' \
  response2.json

# 4. Run greyscale
aws lambda invoke --function-name python_lambda_greyscale \
  --payload '{"bucket_name":"tcss462-image-pipeline-bdiep-group7-local"}' \
  response3.json

# 5. Download final result
aws s3 cp s3://tcss462-image-pipeline-bdiep-group7-local/state3_python.jpeg final_output.jpeg

echo "Pipeline complete! Check final_output.jpeg"
```

---

## Customizing Parameters

### Rotate with different degrees:
```bash
aws lambda invoke --function-name python_lambda_rotate \
  --payload '{"bucket_name":"tcss462-image-pipeline-bdiep-group7-local","input_key":"input_image.jpeg","rotation_degrees":90}' \
  response.json
```

### Resize with specific dimensions:
```bash
aws lambda invoke --function-name python_lambda_resize \
  --payload '{"bucket_name":"tcss462-image-pipeline-bdiep-group7-local","width":1024,"height":768}' \
  response.json
```

### Resize with different scale percentage:
```bash
aws lambda invoke --function-name python_lambda_resize \
  --payload '{"bucket_name":"tcss462-image-pipeline-bdiep-group7-local","scale_percent":200}' \
  response.json
```

---

## Viewing Logs in CloudWatch

To debug or see detailed execution logs:

```bash
# Get recent logs for rotate function
aws logs tail /aws/lambda/python_lambda_rotate --follow

# Get recent logs for resize function
aws logs tail /aws/lambda/python_lambda_resize --follow

# Get recent logs for greyscale function
aws logs tail /aws/lambda/python_lambda_greyscale --follow
```

Or use the AWS Console:
1. Go to CloudWatch → Logs → Log groups
2. Find `/aws/lambda/python_lambda_rotate` (or resize/greyscale)
3. Click on the latest log stream

---

## Updating Functions After Changes

If you modify the code, redeploy:

```bash
cd python_lambda_rotate/deploy
./publish.sh
cd ../..
```

The script will automatically update the existing function.

---

## Troubleshooting

### Error: "An error occurred (InvalidParameterValueException)"
- Check that your IAM Role ARN is correct in config.json
- Verify the role exists: `aws iam get-role --role-name lambda_image_pipeline_role`

### Error: "An error occurred (AccessDeniedException)"
- Verify your AWS CLI credentials: `aws sts get-caller-identity`
- Check you have permissions to create Lambda functions

### Error: "No module named 'PIL'"
- Run `./install_dependencies.sh` again to install Pillow
- Check that `package/` folder has the dependencies

### Error: "Could not find input file"
- Make sure you ran the previous Lambda in the pipeline
- Check S3 for the expected file: `aws s3 ls s3://tcss462-image-pipeline-bdiep-group7-local/`

### Lambda timeout
- Increase timeout in config.json (currently 900 seconds)
- Large images may take longer to process

---

## Cost Considerations

Lambda functions are billed based on:
- Number of requests
- Duration of execution
- Memory allocated

For this tutorial project with small images, costs should be minimal (likely within free tier).

AWS Lambda Free Tier:
- 1 million requests per month
- 400,000 GB-seconds of compute time per month

---

## Cleanup

When done with the project, delete resources:

```bash
# Delete Lambda functions
aws lambda delete-function --function-name python_lambda_rotate
aws lambda delete-function --function-name python_lambda_resize
aws lambda delete-function --function-name python_lambda_greyscale

# Delete S3 bucket contents
aws s3 rm s3://tcss462-image-pipeline-bdiep-group7-local/ --recursive

# Delete S3 bucket
aws s3 rb s3://tcss462-image-pipeline-bdiep-group7-local

# Delete IAM role (detach policies first)
aws iam detach-role-policy --role-name lambda_image_pipeline_role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam detach-role-policy --role-name lambda_image_pipeline_role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
aws iam delete-role --role-name lambda_image_pipeline_role
```

---

## Next Steps

After successful deployment, you can:
1. Test with different image formats (JPEG, PNG)
2. Experiment with different rotation angles and resize scales
3. Monitor performance metrics in CloudWatch
4. Review the SAAF Inspector metrics in the response JSON

Good luck with your TCSS 462 project! 🚀
