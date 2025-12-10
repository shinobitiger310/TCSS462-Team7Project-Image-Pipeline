# Node.js Image Processing Pipeline

A serverless image processing pipeline using AWS Lambda and S3. The pipeline processes images through three stages: rotate, zoom, and greyscale.

## Pipeline Overview

```
tcss462-term-project-group-7-js/input/photo.jpg
    ↓ (S3 trigger)
nodejs_lambda_rotate → tcss462-term-project-group-7-js/stage1/photo.jpg
    ↓ (S3 trigger)
nodejs_lambda_resize → tcss462-term-project-group-7-js/stage2/photo.jpg
    ↓ (S3 trigger)
nodejs_lambda_greyscale → tcss462-term-project-group-7-js/output/photo.jpg
```

## Project Structure

```
nodejs_image_pipeline/
├── src/
│   ├── nodejs_rotate/
|   |    ├── node_modules      # Dependencies
|   |    ├── index.js          # Rotate function
|   |    ├── Inspector.js      # SAAF metrics collector
│   ├── nodejs_resize/
|   |    ├── node_modules      # Dependencies
|   |    ├── index.js          # Resize function
|   |    ├── Inspector.js      # SAAF metrics collector
│   └── nodejs_greyscale/
│        ├── node_modules      # Dependencies
|        ├── index.js          # Greyscale function
|        ├── Inspector.js      # SAAF metrics collector
├── deploy/
│   ├── config.json       # Bucket and their prefixes function settings (EDIT THIS)
│   ├── zip.sh            # Script to create zip files (DON'T USE FOR NOW)
│   ├── nodejs_lambda_greyscale.zip     # READY TO USE FOR LAMBDA, Greyscale Function
|   ├── nodejs_lambda_resize.zip        # READY TO USE FOR LAMBDA, Resize Function
|   └──nodejs_lambda_rotate.zip         # READY TO USE FOR LAMBDA, Rotate Function
│
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

### Step 2: Copy Source Files AND place into structure outline

### Step 3: Create Deploy Files

Create the following files in `deploy/`:

- config.json
- zip.sh
- run.sh

### Step 4: If no dependencies, install Dependencies. SHOULD ALREADY EXIST

```bash
cd deploy
npm init -y
npm install --os=linux --cpu=x64 sharp
npm install aws-sdk uuid@3
```

### Step 5: Make Scripts Executable

```bash
chmod +x zip.sh run.sh
```

### Step 6: Edit Configuration Files

Edit deploy/config files with your bucket and prefixes names:

**deploy/config.json** - Used by scripts

### Step 7: Create Zip Files

```bash
./zip.sh
```


### Step 8: Create Lambda Functions

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

1. Go to S3 → Your bucket → Properties → Event notifications
2. Create 3 event notifications:

Name            | Prefix    | Event Type    | Destination
TriggerRotate   | input/    | PUT           | Lambda for rotate function
TriggerResize   | stage1/    | PUT          | Lambda for resize function
TriggerGrayscale| stage2/    | PUT          | Lambda for greyscale function

---

## Running the Pipeline

```bash
cd deploy
./run.sh photo.jpg
```
# Output
Check the s3 bucket for the photo transformations and the SAAF results

## Updating Functions

When you make changes to source files:

1. Edit files in `src/`
2. Run `./zip.sh`
3. Upload zips to Lambda in AWS Console

---


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
