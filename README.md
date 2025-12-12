# TCSS460-Team7Project-Image-Pipeline

A comparative study of AWS Lambda image processing pipelines across Python, Java, and Node.js runtimes. This project implements a three-stage image transformation pipeline (Rotate → Resize → Greyscale) to analyze performance, cost, and scalability characteristics of different language implementations in serverless environments.

## Project Overview

This repository contains:
- Line-by-line equivalent implementations of image processing functions in Python, Java, and JavaScript
- Automated deployment and testing infrastructure
- CloudWatch log analysis tools for performance metrics extraction
- Scalability testing framework for concurrent workload evaluation

## Prerequisites

- AWS CLI configured with appropriate credentials
- Python 3.x with boto3, Pillow
- Java Development Kit (JDK) 8 or higher
- Node.js and npm
- Bash shell environment
- AWS Lambda execution role with S3 and CloudWatch permissions

## Repository Structure

```
├── python_deployment/     # Python Lambda functions with deployment scripts
├── java_template/         # Java Lambda functions
├── nodejs_template/       # Node.js Lambda functions
├── test/                  # Testing and analysis tools
│   ├── experiments/       # Experiment configuration files
│   ├── functions/         # Function configuration files
│   ├── faas_runner.py     # Main experiment orchestration tool
│   ├── run_performance_tests.sh   # Automated performance test suite
│   ├── queryCloudWatch.py # CloudWatch log analysis
│   ├── analyze_scalability.py     # Scalability metrics analysis
│   └── Kirmizi_Pistachio/ # Test image dataset
└── README.md
```

## Reproducing the Experiments

### Step 1: Deploy Lambda Functions

Each language implementation must be deployed to AWS Lambda. Navigate to the respective template directory and deploy:

**Python Functions:**
```bash
cd python_deployment
# Use the automated deployment script:
./deploy_all_python.sh

# Or deploy manually using the pre-built packages:
aws lambda create-function --function-name python_rotate \
  --runtime python3.9 --handler lambda_function.lambda_handler \
  --memory-size 512 --timeout 30 --role <your-lambda-role-arn> \
  --zip-file fileb://python_lambda_rotate.zip

# Repeat for python_lambda_resize and python_lambda_greyscale
```

See `python_deployment/PYTHON_DEPLOYMENT_GUIDE.md` for detailed instructions.

**Java Functions:**
```bash
cd java_template
# Build and deploy Java functions with similar configuration
# Ensure 512MB memory, appropriate timeouts
```

**JavaScript Functions:**
```bash
cd nodejs_template
# Deploy Node.js functions
cd src/nodejs_rotate
npm install
zip -r function.zip .
aws lambda create-function --function-name nodejs_rotate \
  --runtime nodejs18.x --handler index.handler \
  --memory-size 512 --timeout 30 --role <your-lambda-role-arn> \
  --zip-file fileb://function.zip
```

Repeat for all transformation functions in each language.

### Step 2: Configure S3 Buckets

Create S3 buckets for input and output images:
```bash
aws s3 mb s3://your-input-bucket
aws s3 mb s3://your-output-bucket-python
aws s3 mb s3://your-output-bucket-java
aws s3 mb s3://your-output-bucket-javascript
```

### Step 3: Prepare Test Dataset

Download the Kirmizi Pistachio Image Dataset (500 images) and place in `test/Kirmizi_Pistachio/` directory.

### Step 4: Run Performance Tests

The automated test suite executes experiments across all three languages at multiple concurrency levels:

```bash
cd test
./run_performance_tests.sh
```

This script:
- Tests Python, Java, and JavaScript implementations
- Runs at concurrency levels: 1, 5, 10, 50, 100
- Processes 100 images per batch
- Records test metadata with timestamps
- Waits between batches for Lambda processing and cold start resets

### Step 5: Analyze CloudWatch Logs

After tests complete, extract performance metrics from CloudWatch Logs:

```bash
cd test
python3 queryCloudWatch.py
```

This script:
- Queries CloudWatch Logs for all Lambda invocations
- Extracts execution duration, memory usage, cold start data
- Calculates statistical metrics (mean, std dev, CV)
- Generates detailed performance reports

### Step 6: Generate Reports

Analyze scalability characteristics:
```bash
python3 analyze_scalability.py
```

Compile results:
```bash
python3 compile_results.py <folder_path> <experiment_json>
```

## Experimental Configuration

All Lambda functions are configured identically:
- **Memory:** 512 MB
- **Timeout:** 30 seconds (transformation functions), 900 seconds (upload function)
- **Region:** us-west-2
- **Runtime:** Python 3.9 / Java 11 / Node.js 18.x
- **VPC:** Same VPC for network consistency

Test parameters:
- **Dataset:** 500 images from Kirmizi Pistachio Image Dataset
- **Concurrency Levels:** 1, 5, 10, 50, 100 simultaneous uploads
- **Transformations:** Rotate 90° → Resize to 256×256 → Greyscale conversion

## Output Files

Experiments generate timestamped output files:
- `lambda_performance_report_<timestamp>.txt` - Detailed performance metrics
- `scalability_report_<timestamp>.txt` - Concurrency analysis
- `lambda_performance_data_<timestamp>.json` - Raw JSON data
- `test_metadata_<timestamp>.json` - Test execution metadata

## Data Analysis

Performance metrics collected:
- **Execution Duration:** Min, max, mean, standard deviation, coefficient of variation
- **Memory Utilization:** Average and peak memory usage per invocation
- **Cold Start Rate:** Percentage and frequency of cold starts vs warm starts
- **Cost Estimates:** Per invocation and per 100k invocations
- **Throughput:** Images processed per second
- **Pipeline Duration:** End-to-end processing time

## Cleanup

Remove test artifacts from S3:
```bash
python3 s3cleanup.py
```

Clear CloudWatch log streams:
```bash
python3 cloudwatch_cleanup.py
```

## Citation

If you use this work, please cite:
```
TCSS 462 - Team 7
```

## License

TCSS 462 - Team 7

## Contributors

TCSS462 - Team 7
