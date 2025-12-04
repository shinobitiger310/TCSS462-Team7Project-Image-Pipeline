# Step-by-Step Setup Guide for Image Pipeline Lambda Functions

This guide walks you through setting up the required AWS resources for the Python Image Pipeline project.

## Prerequisites

- AWS CLI installed and configured
- AWS account with appropriate permissions
- Terminal/Command prompt access

Verify AWS CLI is configured:
```bash
aws sts get-caller-identity
```

This should show your AWS account ID and user information.

---

## Step 1: Create an S3 Bucket

### Option A: Using AWS Console (Web Interface)

1. Go to the AWS Console: https://console.aws.amazon.com/
2. Navigate to **S3** service (search "S3" in the top search bar)
3. Click **"Create bucket"**
4. Configure bucket:
   - **Bucket name**: Choose a unique name (e.g., `tcss462-image-pipeline-yourname`)
   - **AWS Region**: Choose your region (e.g., `us-east-2` - Ohio)
   - **Block Public Access**: Keep all boxes checked (recommended for security)
   - Leave other settings as default
5. Click **"Create bucket"**
6. **Save your bucket name** - you'll need this for `config.json`

### Option B: Using AWS CLI

```bash
# Replace with your desired bucket name and region
BUCKET_NAME="tcss462-image-pipeline-yourname"
REGION="us-east-2"

# Create the bucket
aws s3 mb s3://${BUCKET_NAME} --region ${REGION}

# Verify bucket was created
aws s3 ls | grep ${BUCKET_NAME}
```

**Note**: S3 bucket names must be globally unique across all AWS accounts.

---

## Step 2: Create IAM Role for Lambda Functions

### Option A: Using AWS Console (Recommended for Tutorial 6)

#### Step 2.1: Create the IAM Role

1. Go to **IAM** service in AWS Console
2. Click **"Roles"** in the left sidebar
3. Click **"Create role"**
4. Configure the role:
   - **Trusted entity type**: Select **"AWS service"**
   - **Use case**: Select **"Lambda"**
   - Click **"Next"**

#### Step 2.2: Attach Permissions Policies

Search for and select the following policies:

1. **AWSLambdaBasicExecutionRole**
   - Allows Lambda to write logs to CloudWatch

2. **AmazonS3FullAccess** (or create a custom policy for better security - see Option C below)
   - Allows Lambda to read/write to S3

Click **"Next"**

#### Step 2.3: Name and Create the Role

1. **Role name**: `lambda_image_pipeline_role` (or your preferred name)
2. **Description**: "Role for image processing Lambda functions with S3 access"
3. Click **"Create role"**

#### Step 2.4: Get the Role ARN

1. In the IAM Roles list, click on your newly created role
2. Copy the **ARN** shown at the top (it looks like):
   ```
   arn:aws:iam::123456789012:role/lambda_image_pipeline_role
   ```
3. **Save this ARN** - you'll need it for `config.json`

---

### Option B: Using AWS CLI

```bash
# Step 1: Create trust policy document
cat > lambda-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Step 2: Create the IAM role
aws iam create-role \
  --role-name lambda_image_pipeline_role \
  --assume-role-policy-document file://lambda-trust-policy.json

# Step 3: Attach the basic Lambda execution policy
aws iam attach-role-policy \
  --role-name lambda_image_pipeline_role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Step 4: Attach S3 full access policy (or use custom policy below)
aws iam attach-role-policy \
  --role-name lambda_image_pipeline_role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# Step 5: Get the Role ARN (save this!)
aws iam get-role --role-name lambda_image_pipeline_role --query 'Role.Arn' --output text
```

The last command will output your Role ARN. **Save it!**

---

### Option C: Create Custom S3 Policy (More Secure - Recommended)

Instead of using `AmazonS3FullAccess`, create a custom policy that only grants access to your specific bucket:

#### Using AWS Console:

1. In IAM, go to **Policies** → **Create policy**
2. Click **JSON** tab and paste:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:HeadObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::YOUR_BUCKET_NAME/*",
        "arn:aws:s3:::YOUR_BUCKET_NAME"
      ]
    }
  ]
}
```

3. Replace `YOUR_BUCKET_NAME` with your actual bucket name
4. Click **Next**
5. **Policy name**: `LambdaImagePipelineS3Access`
6. Click **Create policy**
7. Go back to your IAM Role and attach this policy instead of `AmazonS3FullAccess`

#### Using AWS CLI:

```bash
# Create the custom policy
BUCKET_NAME="tcss462-image-pipeline-yourname"  # Replace with your bucket name

cat > s3-custom-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:HeadObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}/*",
        "arn:aws:s3:::${BUCKET_NAME}"
      ]
    }
  ]
}
EOF

# Create the policy
aws iam create-policy \
  --policy-name LambdaImagePipelineS3Access \
  --policy-document file://s3-custom-policy.json

# Get your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Attach the custom policy to your role
aws iam attach-role-policy \
  --role-name lambda_image_pipeline_role \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/LambdaImagePipelineS3Access
```

---

## Step 3: Update Configuration Files

Now that you have your **S3 bucket name** and **IAM Role ARN**, update the `config.json` files:

### For python_lambda_rotate/deploy/config.json:

```json
{
	"README": "Configure your Lambda function settings here",

	"functionName": "python_lambda_rotate",
	"handlerFile": "handler.py",

	"lambdaHandler": "lambda_function.lambda_handler",
	"lambdaRoleARN": "arn:aws:iam::123456789012:role/lambda_image_pipeline_role",
	"lambdaSubnets": "",
	"lambdaSecurityGroups": "",
	"lambdaEnvironment": "Variables={}",
	"lambdaRuntime": "python3.14",
	"memorySetting": "512",

	"test": {
		"bucket_name": "tcss462-image-pipeline-yourname",
		"input_key": "input_image.jpeg",
		"rotation_degrees": 180
	}
}
```

### For python_lambda_resize/deploy/config.json:

```json
{
	"README": "Configure your Lambda function settings here",

	"functionName": "python_lambda_resize",
	"handlerFile": "handler.py",

	"lambdaHandler": "lambda_function.lambda_handler",
	"lambdaRoleARN": "arn:aws:iam::123456789012:role/lambda_image_pipeline_role",
	"lambdaSubnets": "",
	"lambdaSecurityGroups": "",
	"lambdaEnvironment": "Variables={}",
	"lambdaRuntime": "python3.14",
	"memorySetting": "512",

	"test": {
		"bucket_name": "tcss462-image-pipeline-yourname",
		"scale_percent": 150
	}
}
```

### For python_lambda_greyscale/deploy/config.json:

```json
{
	"README": "Configure your Lambda function settings here",

	"functionName": "python_lambda_greyscale",
	"handlerFile": "handler.py",

	"lambdaHandler": "lambda_function.lambda_handler",
	"lambdaRoleARN": "arn:aws:iam::123456789012:role/lambda_image_pipeline_role",
	"lambdaSubnets": "",
	"lambdaSecurityGroups": "",
	"lambdaEnvironment": "Variables={}",
	"lambdaRuntime": "python3.14",
	"memorySetting": "512",

	"test": {
		"bucket_name": "tcss462-image-pipeline-yourname",
		"greyscale_mode": "L"
	}
}
```

**Remember to replace:**
- `arn:aws:iam::123456789012:role/lambda_image_pipeline_role` with YOUR actual Role ARN
- `tcss462-image-pipeline-yourname` with YOUR actual bucket name

---

## Step 4: Quick Setup Script (Optional)

Create a script to automate the setup:

```bash
#!/bin/bash

# Configuration
BUCKET_NAME="tcss462-image-pipeline-yourname"  # CHANGE THIS
REGION="us-east-2"  # CHANGE THIS if needed
ROLE_NAME="lambda_image_pipeline_role"

echo "Creating S3 bucket..."
aws s3 mb s3://${BUCKET_NAME} --region ${REGION}

echo "Creating IAM role trust policy..."
cat > lambda-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

echo "Creating IAM role..."
aws iam create-role \
  --role-name ${ROLE_NAME} \
  --assume-role-policy-document file://lambda-trust-policy.json

echo "Attaching policies..."
aws iam attach-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam attach-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

echo "Getting Role ARN..."
ROLE_ARN=$(aws iam get-role --role-name ${ROLE_NAME} --query 'Role.Arn' --output text)

echo ""
echo "===== SETUP COMPLETE ====="
echo "Bucket Name: ${BUCKET_NAME}"
echo "Role ARN: ${ROLE_ARN}"
echo ""
echo "Update your config.json files with these values!"
```

Save as `setup_aws_resources.sh`, make it executable, and run:
```bash
chmod +x setup_aws_resources.sh
./setup_aws_resources.sh
```

---

## Step 5: Verify Setup

```bash
# Verify bucket exists
aws s3 ls | grep your-bucket-name

# Verify role exists
aws iam get-role --role-name lambda_image_pipeline_role

# Verify role has correct policies
aws iam list-attached-role-policies --role-name lambda_image_pipeline_role
```

---

## Next Steps

After completing this setup:

1. ✅ You have an S3 bucket
2. ✅ You have an IAM Role ARN
3. ✅ You've updated all `config.json` files

Now you can proceed to:
1. Install dependencies (see main README)
2. Deploy Lambda functions (see main README)

---

## Cleanup (When Done with Project)

To avoid charges, delete resources when finished:

```bash
# Delete S3 bucket (must be empty first)
aws s3 rb s3://your-bucket-name --force

# Detach policies from role
aws iam detach-role-policy \
  --role-name lambda_image_pipeline_role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam detach-role-policy \
  --role-name lambda_image_pipeline_role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# Delete role
aws iam delete-role --role-name lambda_image_pipeline_role

# Delete Lambda functions
aws lambda delete-function --function-name python_lambda_rotate
aws lambda delete-function --function-name python_lambda_resize
aws lambda delete-function --function-name python_lambda_greyscale
```

---

## Troubleshooting

### Error: "Bucket name already exists"
S3 bucket names are globally unique. Try a different name.

### Error: "Role already exists"
Either use the existing role or choose a different name.

### Error: "Access Denied"
Your AWS user may not have permission to create IAM roles. Contact your AWS administrator or use the AWS Console.

### Permission Issues in Lambda
Make sure your IAM role has both:
- AWSLambdaBasicExecutionRole (for CloudWatch logs)
- S3 access policy (for reading/writing images)
