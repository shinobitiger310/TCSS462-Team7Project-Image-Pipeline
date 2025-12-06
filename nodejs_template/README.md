# Node.js Image Processing Pipeline

A serverless image processing pipeline using AWS Lambda and S3. The pipeline processes images through three stages: rotate, zoom, and greyscale.

## Pipeline Overview

```
YOUR-INPUT-BUCKET/photo.jpg
    ↓ (S3 trigger)
nodejs_lambda_rotate → YOUR-STAGE1-BUCKET/photo.jpg
    ↓ (S3 trigger)
nodejs_lambda_resize → YOUR-STAGE2-BUCKET/photo.jpg
    ↓ (S3 trigger)
nodejs_lambda_greyscale → YOUR-OUTPUT-BUCKET/photo.jpg
```

## Project Structure

```
nodejs_image_pipeline/
├── src/
│   ├── config.js         # Bucket configuration (EDIT THIS)
│   ├── rotate.js         # Rotate function (180 degrees)
│   ├── zoom.js           # Zoom function (50% center crop)
│   ├── greyscale.js      # Greyscale function
│   └── Inspector.js      # SAAF metrics collector
├── deploy/
│   ├── zip.sh            # Script to create zip files
│   └── node_modules/     # Dependencies (generated)
└── README.md
```

## Prerequisites

- Node.js 20.x (use `nvm install 20` if needed)
- AWS CLI configured with credentials
- AWS account with Lambda and S3 access

---

## Setup Instructions

### Step 1: Create S3 Buckets

Create 4 buckets in AWS S3 Console:

| Bucket | Purpose |
|--------|---------|
| YOUR-INPUT-BUCKET | Upload original images |
| YOUR-STAGE1-BUCKET | After rotate |
| YOUR-STAGE2-BUCKET | After zoom |
| YOUR-OUTPUT-BUCKET | Final processed images |

### Step 2: Create Project Folders

```bash
mkdir -p nodejs_image_pipeline/src nodejs_image_pipeline/deploy
cd nodejs_image_pipeline
```

### Step 3: Create Source Files

Create the following files in the `src/` folder.

#### src/config.js

**IMPORTANT: Replace bucket names with your own!**

#### src/rotate.js

#### src/zoom.js

#### src/greyscale.js

#### src/Inspector.js

Copy your existing SAAF Inspector.js file to the `src/` folder.

### Step 4: Create Zip Script

Create `deploy/zip.sh` or use the one in deploy/zip.sh:

### Step 5: Install Dependencies

```bash
cd deploy
npm init -y
npm install @aws-sdk/client-s3 uuid@3
npm install --os=linux --cpu=x64 sharp
```

**Important:**
- `uuid@3` is required for Inspector.js compatibility
- `--os=linux --cpu=x64` is required for Sharp to work in Lambda

### Step 6: Make Script Executable

```bash
chmod +x zip.sh
```

### Step 7: Edit config.js

Edit `src/config.js` and replace the placeholder bucket names with your actual bucket names.

### Step 8: Create Zip Files

```bash
./zip.sh
```

This creates:
- `rotate-function.zip`
- `zoom-function.zip`
- `greyscale-function.zip`

### Step 9: Create Lambda Functions

For each function in AWS Console:

1. Go to **Lambda** → **Create function**
2. Select **Author from scratch**
3. Configure:

| Function | Name | Runtime |
|----------|------|---------|
| Rotate | nodejs_lambda_rotate | Node.js 20.x |
| Zoom | nodejs_lambda_resize | Node.js 20.x |
| Greyscale | nodejs_lambda_greyscale | Node.js 20.x |

4. Click **Create function**

### Step 10: Upload Zip Files

For each function:

1. Go to Lambda function → **Code** tab
2. Click **Upload from** → **.zip file**
3. Upload:

| Function | Zip File |
|----------|----------|
| nodejs_lambda_rotate | rotate-function.zip |
| nodejs_lambda_resize | zoom-function.zip |
| nodejs_lambda_greyscale | greyscale-function.zip |

### Step 11: Configure Lambda Settings

For each function:

1. Go to **Configuration** → **General configuration** → **Edit**
2. Set:
   - Timeout: **1 minute 30 seconds**
   - Memory: **1024 MB**
3. Click **Save**

### Step 12: Add S3 Permissions

For each function:

1. Go to **Configuration** → **Permissions**
2. Click the role name (opens IAM)
3. Click **Add permissions** → **Attach policies**
4. Add **AmazonS3FullAccess**
5. Click **Add permissions**

### Step 13: Add S3 Triggers

For each function:

1. Go to **Configuration** → **Triggers**
2. Click **Add trigger**
3. Select **S3**
4. Configure:

| Function | Bucket | Event Type |
|----------|--------|------------|
| nodejs_lambda_rotate | YOUR-INPUT-BUCKET | PUT |
| nodejs_lambda_resize | YOUR-STAGE1-BUCKET | PUT |
| nodejs_lambda_greyscale | YOUR-STAGE2-BUCKET | PUT |

5. Click **Add**

---

## Testing

### Upload an Image

```bash
aws s3 cp photo.jpg s3://YOUR-INPUT-BUCKET/
```

### Check Results

```bash
aws s3 ls s3://YOUR-STAGE1-BUCKET/
aws s3 ls s3://YOUR-STAGE2-BUCKET/
aws s3 ls s3://YOUR-OUTPUT-BUCKET/
```

### Download Final Image

```bash
aws s3 cp s3://YOUR-OUTPUT-BUCKET/photo.jpg ./result.jpg
```

---

## Updating Functions

When you make changes to source files:

1. Edit the files in `src/`
2. Run `./zip.sh` in the deploy folder
3. Upload each zip to its Lambda function in AWS Console

---

## Functions Summary

| Function | Input Bucket | Output Bucket | Action |
|----------|--------------|---------------|--------|
| nodejs_lambda_rotate | YOUR-INPUT-BUCKET | YOUR-STAGE1-BUCKET | Rotate 180° |
| nodejs_lambda_resize | YOUR-STAGE1-BUCKET | YOUR-STAGE2-BUCKET | Zoom 50% center crop |
| nodejs_lambda_greyscale | YOUR-STAGE2-BUCKET | YOUR-OUTPUT-BUCKET | Convert to greyscale |

## Lambda Configuration

| Setting | Value |
|---------|-------|
| Runtime | Node.js 20.x |
| Handler | index.handler |
| Timeout | 1 min 30 sec |
| Memory | 1024 MB |

---

## Troubleshooting

### Sharp Module Error

```
Could not load the "sharp" module using the linux-x64 runtime
```

**Fix:**

```bash
cd deploy
rm -rf node_modules
npm install @aws-sdk/client-s3 uuid@3
npm install --os=linux --cpu=x64 sharp
./zip.sh
```

Re-upload the zip files.

### uuid/v4 Error

```
Package subpath './v4' is not defined by exports
```

**Fix:** Use `uuid@3`:

```bash
npm install uuid@3
```

### Timeout Error

```
Sandbox.Timedout
```

**Fix:**
1. Increase timeout to 1 min 30 sec
2. Increase memory to 1024 MB
3. Check S3 permissions

### No Image in Next Bucket

**Check:**
1. CloudWatch logs for errors
2. S3 permissions are set
3. Bucket names match in config.js
4. config.js is included in the zip

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| @aws-sdk/client-s3 | latest | S3 operations |
| sharp | latest | Image processing |
| uuid | 3.x | UUID for Inspector.js |

---

## SAAF Inspector Output

Each function returns metrics in the Lambda response:

```json
{
  "version": 0.5,
  "lang": "node.js",
  "startTime": 1733400000000,
  "uuid": "abc12345-1234-5678-abcd-123456789abc",
  "newcontainer": 1,
  "platform": "AWS Lambda",
  "functionName": "nodejs_lambda_rotate",
  "functionMemory": "1024",
  "functionRegion": "us-east-1",
  "inputBucket": "YOUR-INPUT-BUCKET",
  "outputBucket": "YOUR-STAGE1-BUCKET",
  "inputKey": "photo.jpg",
  "outputKey": "photo.jpg",
  "message": "Image rotated successfully",
  "runtime": 1234,
  "endTime": 1733400001234
}
```

View this output in:
- AWS Console → Lambda → Test tab → Execution results
- CloudWatch Logs

---

## Quick Reference

### Setup Commands

```bash
mkdir -p nodejs_image_pipeline/src nodejs_image_pipeline/deploy
cd nodejs_image_pipeline
# Create source files in src/
# Create zip.sh in deploy/
cd deploy
npm init -y
npm install @aws-sdk/client-s3 uuid@3
npm install --os=linux --cpu=x64 sharp
chmod +x zip.sh
# Edit src/config.js with your bucket names
./zip.sh
# Upload zips to Lambda in AWS Console
```

### Test Commands

```bash
aws s3 cp photo.jpg s3://YOUR-INPUT-BUCKET/
aws s3 ls s3://YOUR-OUTPUT-BUCKET/
aws s3 cp s3://YOUR-OUTPUT-BUCKET/photo.jpg ./result.jpg
```

---

## License

MIT
