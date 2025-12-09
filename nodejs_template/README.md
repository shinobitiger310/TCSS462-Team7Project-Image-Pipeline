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
│   ├── config.json       # Bucket and function settings (EDIT THIS)
│   ├── zip.sh            # Script to create zip files
│   ├── run.sh            # Script to run the pipeline
│   └── node_modules/     # Dependencies
└── README.md
```

## Prerequisites

- Node.js 20.x
- AWS CLI configured with credentials
- AWS account with Lambda and S3 access
- jq installed (`sudo apt install jq`)

---

## Setup Instructions

### Step 1: Create Project Folders

```bash
mkdir -p nodejs_image_pipeline/src nodejs_image_pipeline/deploy
cd nodejs_image_pipeline
```

### Step 2: Copy Source Files

Create the following files in `src/`:

- config.js
- rotate.js
- zoom.js
- greyscale.js
- Inspector.js (copy your SAAF Inspector.js)

### Step 3: Create Deploy Files

Create the following files in `deploy/`:

- config.json
- zip.sh
- run.sh

### Step 4: If no dependencies, install Dependencies. SHOULD ALREADY EXIST

```bash
cd deploy
npm init -y
npm install @aws-sdk/client-s3 uuid@3
npm install --os=linux --cpu=x64 sharp
```

### Step 5: Make Scripts Executable

```bash
chmod +x zip.sh run.sh
```

### Step 6: Edit Configuration Files

Edit both config files with your bucket names:

**src/config.js** - Used by Lambda functions
**deploy/config.json** - Used by scripts

### Step 7: Create Zip Files

```bash
./zip.sh
```

### Step 8: Create S3 Buckets

Create 4 buckets in AWS S3 Console:

| Bucket | Purpose |
|--------|---------|
| YOUR-INPUT-BUCKET | Upload original images |
| YOUR-STAGE1-BUCKET | After rotate |
| YOUR-STAGE2-BUCKET | After zoom |
| YOUR-OUTPUT-BUCKET | Final processed images |

### Step 9: Create Lambda Functions

Create 3 functions in AWS Lambda Console:

| Name | Runtime |
|------|---------|
| nodejs_lambda_rotate | Node.js 20.x |
| nodejs_lambda_resize | Node.js 20.x |
| nodejs_lambda_greyscale | Node.js 20.x |

### Step 10: Upload Zip Files

For each function:

1. Go to **Code** tab
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
2. Click the role name
3. Click **Add permissions** → **Attach policies**
4. Add **AmazonS3FullAccess**

### Step 13: Add S3 Triggers

| Function | Trigger Bucket | Event Type |
|----------|----------------|------------|
| nodejs_lambda_rotate | YOUR-INPUT-BUCKET | PUT |
| nodejs_lambda_resize | YOUR-STAGE1-BUCKET | PUT |
| nodejs_lambda_greyscale | YOUR-STAGE2-BUCKET | PUT |

---

## Running the Pipeline

```bash
cd deploy
./run.sh photo.jpg
```

**Output:**

```
===== Image Processing Pipeline =====

Uploading photo.jpg...
upload: ./photo.jpg to s3://your-input-bucket/photo.jpg

Waiting for pipeline to complete...

===== SAAF Output =====

----- Rotate -----
{
  "version": 0.5,
  "lang": "node.js",
  "uuid": "abc12345-1234-5678-abcd-123456789abc",
  "newcontainer": 1,
  "platform": "AWS Lambda",
  "functionName": "nodejs_lambda_rotate",
  "functionMemory": "1024",
  "inputBucket": "your-input-bucket",
  "outputBucket": "your-stage1-bucket",
  "message": "Image rotated successfully",
  "runtime": 1234
}

----- Zoom -----
{
  ...
}

----- Greyscale -----
{
  ...
}

===== Pipeline Complete =====

Download result:
  aws s3 cp s3://your-output-bucket/photo.jpg ./
```

---

## Download Result

```bash
aws s3 cp s3://YOUR-OUTPUT-BUCKET/photo.jpg ./result.jpg
```

---

## Updating Functions

When you make changes to source files:

1. Edit files in `src/`
2. Run `./zip.sh`
3. Upload zips to Lambda in AWS Console

---

## Functions Summary

| Function | Input | Output | Action |
|----------|-------|--------|--------|
| nodejs_lambda_rotate | INPUT-BUCKET | STAGE1-BUCKET | Rotate 180° |
| nodejs_lambda_resize | STAGE1-BUCKET | STAGE2-BUCKET | Zoom 50% |
| nodejs_lambda_greyscale | STAGE2-BUCKET | OUTPUT-BUCKET | Greyscale |

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

```bash
cd deploy
rm -rf node_modules
npm instalbl @aws-sdbk/client-s3 uuid@3
npm install --os=linux --cpu=x64 sharp
./zip.sh
```

Re-upload zips.

### Timeout Error

Increase timeout to 1 min 30 sec and memory to 1024 MB.

### No SAAF Output

Make sure functions have `console.log(JSON.stringify(result))` before return.

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| @aws-sdk/client-s3 | latest | S3 operations |
| sharp | latest | Image processing |
| uuid | 3.x | UUID for Inspector.js |

---
