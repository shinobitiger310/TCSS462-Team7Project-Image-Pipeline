# Manual Lambda Deployment Guide

This guide shows you how to create deployment packages (ZIP files) and manually upload them to AWS Lambda through the AWS Console.

## Step 1: Create Deployment Packages

Run the script to create ZIP files for all three Lambda functions:

```bash
cd python_deployment
./create_deployment_packages.sh
```

This will create three ZIP files:
- `python_lambda_rotate.zip` (~13 MB)
- `python_lambda_resize.zip` (~13 MB)
- `python_lambda_greyscale.zip` (~13 MB)

## Step 2: Create Lambda Functions in AWS Console

### For python_lambda_rotate:

1. **Go to AWS Lambda Console**: https://console.aws.amazon.com/lambda/
2. **Click "Create function"**
3. **Configure the function:**
   - Function name: `python_lambda_rotate`
   - Runtime: **Python 3.12**
   - Architecture: **x86_64**
   - Execution role: **Use an existing role**
   - Existing role: `LambdaS3` (or `arn:aws:iam::940336903991:role/LambdaS3`)
4. **Click "Create function"**

5. **Upload the deployment package:**
   - In the "Code" section, click **"Upload from"** → **".zip file"**
   - Click **"Upload"** and select `python_lambda_rotate.zip`
   - Click **"Save"**

6. **Configure function settings:**
   - Click the **"Configuration"** tab
   - Go to **"General configuration"** → Click **"Edit"**
   - Memory: **512 MB**
   - Timeout: **15 min 0 sec** (900 seconds)
   - Click **"Save"**

7. **Set handler (if needed):**
   - In "Runtime settings" → Click **"Edit"**
   - Handler: `lambda_function.lambda_handler`
   - Click **"Save"**

### For python_lambda_resize:

Repeat the same steps as above, but:
- Function name: `python_lambda_resize`
- Upload: `python_lambda_resize.zip`
- Keep all other settings the same

### For python_lambda_greyscale:

Repeat the same steps as above, but:
- Function name: `python_lambda_greyscale`
- Upload: `python_lambda_greyscale.zip`
- Keep all other settings the same

## Step 3: Test the Functions

### Test python_lambda_rotate:

1. Go to the function's **"Test"** tab
2. Create a new test event:
   - Event name: `RotateTest`
   - Event JSON:
   ```json
   {
     "bucket_name": "tcss462-term-project-group-7",
     "input_key": "input_image.jpeg",
     "rotation_degrees": 180
   }
   ```
3. Click **"Save"**
4. Click **"Test"**

### Test python_lambda_resize:

1. Go to the function's **"Test"** tab
2. Create a new test event:
   - Event name: `ResizeTest`
   - Event JSON:
   ```json
   {
     "bucket_name": "tcss462-term-project-group-7",
     "scale_percent": 150
   }
   ```
3. Click **"Save"**
4. Click **"Test"**

### Test python_lambda_greyscale:

1. Go to the function's **"Test"** tab
2. Create a new test event:
   - Event name: `GreyscaleTest`
   - Event JSON:
   ```json
   {
     "bucket_name": "tcss462-term-project-group-7",
     "greyscale_mode": "L"
   }
   ```
3. Click **"Save"**
4. Click **"Test"**

## Step 4: Upload Test Image to S3

Before testing, upload a test image:

```bash
aws s3 cp input_image.jpeg s3://tcss462-term-project-group-7/
```

Or upload through S3 Console:
1. Go to S3 Console
2. Open bucket `tcss462-term-project-group-7`
3. Click **"Upload"**
4. Select `input_image.jpeg`
5. Click **"Upload"**

## Step 5: Run the Complete Pipeline

Run the functions in order:

1. **Rotate**: Processes `input_image.jpeg` → creates `stage1/input_image.jpeg`
2. **Resize**: Processes `stage1/input_image.jpeg` → creates `stage2/input_image.jpeg`
3. **Greyscale**: Processes `stage2/input_image.jpeg` → creates `output/input_image.jpeg`

You can also use the test scripts:

```bash
cd python_deployment
./test_python_all.sh
```

## Deployment Package Contents

Each ZIP file contains:
- `lambda_function.py` - Main Lambda handler
- `handler.py` - Image processing logic
- `Inspector.py` - SAAF metrics collection
- `PIL/` - Pillow image processing library
- `pillow.libs/` - Pillow binary dependencies

## Configuration Summary

All three Lambda functions should be configured with:

| Setting | Value |
|---------|-------|
| Runtime | Python 3.12 |
| Handler | lambda_function.lambda_handler |
| Memory | 512 MB |
| Timeout | 900 seconds (15 minutes) |
| IAM Role | LambdaS3 |
| S3 Bucket | tcss462-term-project-group-7 |

## Updating Functions

To update a function after changing code:

1. Run `./create_deployment_packages.sh` again
2. Go to the Lambda function in AWS Console
3. Click **"Upload from"** → **".zip file"**
4. Upload the new ZIP file
5. Click **"Save"**

## Troubleshooting

### ZIP file too large
If the ZIP file is over 50 MB and you can't upload directly:
1. Upload to S3 first:
   ```bash
   aws s3 cp python_lambda_rotate.zip s3://tcss462-term-project-group-7/
   ```
2. In Lambda Console, choose **"Upload from"** → **"Amazon S3 location"**
3. Enter: `s3://tcss462-term-project-group-7/python_lambda_rotate.zip`

### Function timeout
- Increase timeout in Configuration → General configuration
- Maximum is 15 minutes (900 seconds)

### Permission errors
- Verify IAM role `LambdaS3` has:
  - `AmazonS3FullAccess` policy
  - `AWSLambdaBasicExecutionRole` policy

### Module not found errors
- Recreate deployment package: `./create_deployment_packages.sh`
- Ensure dependencies were installed correctly

## Advantages of Manual Deployment

✅ **Visual feedback** - See deployment progress in AWS Console
✅ **Easy configuration** - Click-based configuration, no CLI needed
✅ **Quick updates** - Drag and drop ZIP files to update
✅ **Version control** - Can keep ZIP files for rollback
✅ **Good for learning** - Understand Lambda configuration better

## Disadvantages of Manual Deployment

❌ **Time consuming** - Must configure each function individually
❌ **Error prone** - Easy to misconfigure settings
❌ **Not automated** - Can't script or CI/CD deploy
❌ **Harder to maintain** - Multiple functions to manage

For production or frequent updates, use the automated deployment script:
```bash
./deploy_all_python.sh
```
