# S3 Trigger Setup Guide for Python Image Pipeline

This guide explains how to configure S3 triggers to automatically run the image processing pipeline, similar to the Java pipeline setup.

## Overview

With S3 triggers configured, the pipeline runs **automatically** when you upload an image to the S3 `input/` folder:

1. Upload image to `input/` → **python_lambda_rotate** triggers automatically → saves to `stage1/`
2. File appears in `stage1/` → **python_lambda_resize** triggers automatically → saves to `stage2/`
3. File appears in `stage2/` → **python_lambda_greyscale** triggers automatically → saves to `output/`

**Result:** Upload one image, get fully processed output without manual Lambda invocation!

## Prerequisites

- All three Lambda functions deployed
- S3 bucket: `tcss462-term-project-group-7` (or your configured bucket)
- IAM role with proper S3 permissions configured (e.g., `lambda_image_pipeline_role` or `LambdaS3`)

## Code Changes

All three Lambda handlers have been updated to support **both** invocation methods:

### ✅ Manual Invocation (Testing)
Still works with existing test scripts:
```json
{
  "bucket_name": "tcss462-term-project-group-7",
  "rotation_degrees": 180
}
```

### ✅ S3 Trigger (Automated)
Automatically extracts bucket and file info from S3 event:
```json
{
  "Records": [
    {
      "s3": {
        "bucket": {"name": "tcss462-term-project-group-7"},
        "object": {"key": "input/myimage.jpg"}
      }
    }
  ]
}
```

## Step-by-Step Setup

### Function 1: python_lambda_rotate

#### 1. Add S3 Trigger
1. Go to AWS Lambda Console → **python_lambda_rotate**
2. Click **Add trigger**
3. Select **S3** from the dropdown
4. Configure:
   - **Bucket:** `tcss462-term-project-group-7`
   - **Event type:** PUT
   - **Prefix:** `input/`
   - **Suffix:** Leave empty (processes .jpg, .jpeg, .png)
5. Acknowledge the warning about S3 permissions
6. Click **Add**

#### 2. Set Environment Variables (Optional)
1. Go to **Configuration** → **Environment variables**
2. Click **Edit** → **Add environment variable**
3. Add:
   - **Key:** `ROTATION_DEGREES`
   - **Value:** `180` (or your preferred default)
4. Click **Save**

#### 3. Verify IAM Permissions
All functions share the same IAM role with S3 permissions.

---

### Function 2: python_lambda_resize

#### 1. Add S3 Trigger
1. Go to AWS Lambda Console → **python_lambda_resize**
2. Click **Add trigger**
3. Select **S3**
4. Configure:
   - **Bucket:** `tcss462-term-project-group-7`
   - **Event type:** PUT
   - **Prefix:** `stage1/`
   - **Suffix:** Leave empty
5. Click **Add**

#### 2. Set Environment Variables (Optional)
Add these environment variables:
- **Key:** `SCALE_PERCENT`, **Value:** `150`
- **Key:** `WIDTH`, **Value:** (leave empty or set specific width)
- **Key:** `HEIGHT`, **Value:** (leave empty or set specific height)

#### 3. Verify IAM Permissions
All functions share the same IAM role with S3 permissions.

---

### Function 3: python_lambda_greyscale

#### 1. Add S3 Trigger
1. Go to AWS Lambda Console → **python_lambda_greyscale**
2. Click **Add trigger**
3. Select **S3**
4. Configure:
   - **Bucket:** `tcss462-term-project-group-7`
   - **Event type:** PUT
   - **Prefix:** `stage2/`
   - **Suffix:** Leave empty
5. Click **Add**

#### 2. Set Environment Variables (Optional)
Add environment variable:
- **Key:** `GREYSCALE_MODE`, **Value:** `L` (or `1` for binary)

#### 3. Verify IAM Permissions
All functions share the same IAM role with S3 permissions.

---

## Testing the Automated Pipeline

### Upload a Test Image via S3 Console

1. **Open S3 Console**
   - Go to: https://console.aws.amazon.com/s3/

2. **Navigate to Bucket**
   - Click on `tcss462-term-project-group-7`
   - Click on `input/` folder

3. **Upload Image**
   - Click **Upload**
   - Click **Add files**
   - Select your test image (e.g., `test-trigger.jpg`)
   - Click **Upload**

4. **Wait ~10-30 seconds** for processing

5. **Check Results**
   - Go back to bucket root
   - Check `stage1/` folder → should see `test-trigger.jpg` (~5 sec)
   - Check `stage2/` folder → should see `test-trigger.jpg` (~10 sec)
   - Check `output/` folder → should see `test-trigger.jpg` (~15 sec)

6. **Download Final Result**
   - Click on `output/test-trigger.jpg`
   - Click **Download**

### Via AWS CLI

```bash
# Upload an image to trigger the pipeline
aws s3 cp myimage.jpg s3://tcss462-term-project-group-7/input/

# Wait ~10-30 seconds for processing

# Check final output
aws s3 ls s3://tcss462-term-project-group-7/output/

# Download processed image
aws s3 cp s3://tcss462-term-project-group-7/output/myimage.jpg ./final_output.jpg
```

### Monitor Execution in AWS Console

#### CloudWatch Logs:

1. **Open CloudWatch Console**
   - Go to: https://console.aws.amazon.com/cloudwatch/

2. **Navigate to Log Groups**
   - Click **Logs** → **Log groups**

3. **Check Each Function's Logs**
   - `/aws/lambda/python_lambda_rotate`
   - `/aws/lambda/python_lambda_resize`
   - `/aws/lambda/python_lambda_greyscale`

4. **Look for Success Indicators:**
   - `"trigger_type": "s3_event"` ← Confirms S3 trigger worked!
   - `"input_key": "input/test-trigger.jpg"`
   - `"output_key": "stage1/test-trigger.jpg"`
   - `"message": "Successfully rotated..."`

## Verifying S3 Triggers

Check that triggers are properly configured:

### In Lambda Console:
1. Go to each Lambda function
2. Check **Function overview** diagram at top
3. Should show S3 icon connected to Lambda function

### In S3 Console:
1. Go to S3 → Bucket → **Properties** tab
2. Scroll to **Event notifications** section
3. Should see three notifications:
   - One for `input/` prefix → python_lambda_rotate
   - One for `stage1/` prefix → python_lambda_resize
   - One for `stage2/` prefix → python_lambda_greyscale

## Deployment After Code Changes

After updating the handler code to support S3 triggers, redeploy:

```bash
cd python_deployment

# Option 1: Automated deployment
./deploy_all_python.sh

# Option 2: Manual deployment (rebuild packages and upload via AWS Console)
./create_deployment_packages.sh
# Then upload the ZIP files in AWS Lambda Console
```

## Comparison: Manual vs Automated

### Manual Invocation (Original)
```bash
# Upload image
aws s3 cp myimage.jpg s3://bucket/input/

# Manually invoke each function
aws lambda invoke --function-name python_lambda_rotate --payload '{"bucket_name":"bucket"}' response1.json
aws lambda invoke --function-name python_lambda_resize --payload '{"bucket_name":"bucket"}' response2.json
aws lambda invoke --function-name python_lambda_greyscale --payload '{"bucket_name":"bucket"}' response3.json
```

### S3 Trigger (Automated)
```bash
# Just upload image - everything else happens automatically!
aws s3 cp myimage.jpg s3://bucket/input/

# Wait ~10-30 seconds, then download result
aws s3 cp s3://bucket/output/myimage.jpg ./final_output.jpg
```

## Troubleshooting

### Trigger Not Firing

**Check S3 event notification configuration via Console:**
1. S3 Console → Bucket → Properties → Event notifications
2. Verify all three notifications exist with correct prefixes

**Verify IAM permissions:**
- Lambda execution role must have `s3:GetObject`, `s3:PutObject`, `s3:ListBucket`

### Function Errors

**Check CloudWatch Logs via Console:**
1. CloudWatch → Log groups → `/aws/lambda/[function-name]`
2. Click most recent log stream

**Common issues:**
- `trigger_type: s3_event` attribute in logs confirms S3 trigger is working
- `trigger_type: manual_invoke` means function was called manually (test script)
- Missing environment variables will use defaults
- Empty folder markers (0-byte objects) are automatically skipped

### Multiple Invocations

If you see the same file processed multiple times:
- Check for duplicate S3 triggers in Lambda Console
- Verify prefix filters are correct (`input/`, `stage1/`, `stage2/`)

### Java and Python Pipeline Conflict

**Issue:** Both Java and Python functions trigger on same prefixes

**Solution:** Disable Java S3 triggers (keep only Python triggers enabled)

1. Go to each Java Lambda function
2. Configuration → Triggers → Delete S3 trigger
3. Keep Python triggers active

## Benefits of S3 Triggers

1. **Fully Automated:** No manual Lambda invocation needed
2. **Scalable:** Processes multiple images independently
3. **Event-Driven:** Functions only run when needed (cost-effective)
4. **Parallel Processing:** Multiple images can flow through pipeline simultaneously
5. **Matches Java Pipeline:** Same architecture and behavior

## Cleanup

To remove S3 triggers:

### Via Lambda Console:
1. Lambda → Function → Configuration → Triggers
2. Click on S3 trigger
3. Click **Delete**
4. Repeat for all three functions

### Via S3 Console:
1. S3 → Bucket → Properties → Event notifications
2. Select notification
3. Click **Delete**

## Next Steps

1. ✅ Deploy updated Lambda functions with S3 trigger support
2. ✅ Configure S3 triggers for all three functions
3. ✅ Test with sample images
4. ✅ Monitor CloudWatch logs for successful execution
5. 🎉 Enjoy fully automated image processing!

---

**Note:** The Python pipeline now has feature parity with the Java pipeline. Both support the same automated S3 trigger workflow!
