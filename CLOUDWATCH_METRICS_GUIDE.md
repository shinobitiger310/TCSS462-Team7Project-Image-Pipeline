# CloudWatch Metrics Collection Guide

Complete guide for collecting all required performance metrics using CloudWatch Logs Insights.

## Overview

All Lambda functions now log pipeline tracking metrics via the SAAF Inspector framework. You can extract comprehensive performance data using CloudWatch Logs Insights queries - no additional code needed!

## What's Already Tracked

Every function invocation logs:
- `runtime` - Total function execution time (ms)
- `newcontainer` - Cold start flag (1 = cold, 0 = warm)
- `image_id` - Filename of the image being processed
- `pipeline_stage` - Which stage (rotate, resize, greyscale)
- `functionName` - Lambda function name
- `functionMemory` - Memory allocation (MB)
- `functionRegion` - AWS region
- `startTime` / `endTime` - Timestamps (epoch ms)
- Plus CPU, memory, and other SAAF metrics

---

## CloudWatch Logs Insights Queries

### 1. Runtime Statistics per Function (avg, std dev, CV)

**What it measures:** Average runtime, standard deviation, coefficient of variation

```sql
fields @timestamp, functionName, runtime
| filter @message like /INSPECTOR METRICS/
| parse @message '"runtime": *,' as runtime_ms
| parse @message '"functionName": "*"' as functionName
| stats
    count() as invocations,
    avg(runtime_ms) as avg_runtime_ms,
    stddev(runtime_ms) as stddev_runtime_ms,
    min(runtime_ms) as min_runtime_ms,
    max(runtime_ms) as max_runtime_ms,
    pct(runtime_ms, 50) as median_runtime_ms,
    pct(runtime_ms, 95) as p95_runtime_ms,
    pct(runtime_ms, 99) as p99_runtime_ms
  by functionName
| fields functionName, invocations, avg_runtime_ms, stddev_runtime_ms,
         min_runtime_ms, max_runtime_ms, median_runtime_ms, p95_runtime_ms, p99_runtime_ms
| sort avg_runtime_ms desc
```

**Calculate CV (Coefficient of Variation):**
```
CV = (stddev_runtime_ms / avg_runtime_ms) × 100%
```

**Example output:**
```
functionName            | avg_runtime_ms | stddev_ms | CV
-----------------------|----------------|-----------|-------
python_lambda_greyscale|  312.4         |  15.2     | 4.87%
python_lambda_resize   |  387.2         |  22.1     | 5.71%
python_lambda_rotate   |  245.3         |  12.4     | 5.05%
```

---

### 2. Cold Start vs. Warm Start Comparison

**What it measures:** Performance difference between cold and warm starts

```sql
fields @timestamp, functionName, runtime, newcontainer
| filter @message like /INSPECTOR METRICS/
| parse @message '"runtime": *,' as runtime_ms
| parse @message '"functionName": "*"' as functionName
| parse @message '"newcontainer": *,' as is_cold_start
| stats
    avg(runtime_ms) as avg_runtime_ms,
    stddev(runtime_ms) as stddev_ms,
    count() as count
  by functionName, is_cold_start
| sort functionName, is_cold_start
```

**Interpretation:**
- `is_cold_start = 1` → Cold start (new container, after >5 min idle)
- `is_cold_start = 0` → Warm start (container reuse)

**Example output:**
```
functionName            | is_cold_start | avg_runtime_ms | count
-----------------------|---------------|----------------|------
python_lambda_rotate   | 0             | 210.3          | 180
python_lambda_rotate   | 1             | 892.7          | 20
```

**Analysis:** Cold starts are ~4.2x slower than warm starts.

---

### 3. End-to-End Pipeline Latency

**What it measures:** Total time from rotate start to greyscale completion

```sql
fields @timestamp, image_id, pipeline_stage, startTime, endTime
| filter @message like /INSPECTOR METRICS/
| parse @message '"image_id": "*"' as image_id
| parse @message '"pipeline_stage": "*"' as stage
| parse @message '"startTime": *,' as start_time
| parse @message '"endTime": *,' as end_time
| stats
    earliest(start_time) as pipeline_start,
    latest(end_time) as pipeline_end
  by image_id
| fields image_id,
         (pipeline_end - pipeline_start) / 1000 as pipeline_latency_seconds
| stats
    avg(pipeline_latency_seconds) as avg_pipeline_latency_s,
    stddev(pipeline_latency_seconds) as stddev_s,
    min(pipeline_latency_seconds) as min_s,
    max(pipeline_latency_seconds) as max_s
```

**Example output:**
```
avg_pipeline_latency_s | stddev_s | min_s  | max_s
-----------------------|----------|--------|-------
2.34                   | 0.42     | 1.82   | 4.91
```

---

### 4. Cost Estimates

**What it measures:** Projected cost for 100k images based on actual runtime

**Step 1: Get average runtime and memory from CloudWatch**

```sql
fields functionName, runtime, functionMemory
| filter @message like /INSPECTOR METRICS/
| parse @message '"functionName": "*"' as functionName
| parse @message '"runtime": *,' as runtime_ms
| parse @message '"functionMemory": "*"' as memory_mb
| stats
    count() as invocations,
    avg(runtime_ms) as avg_runtime_ms,
    avg(memory_mb) as avg_memory_mb
  by functionName
```

**Step 2: Calculate cost (AWS Lambda pricing - us-west-2, 2024)**

**Pricing:**
- **Requests:** $0.20 per 1M requests
- **Compute:** $0.0000166667 per GB-second

**Formula:**
```
Request cost = (invocations / 1,000,000) × $0.20
Compute cost = invocations × (memory_mb / 1024) × (avg_runtime_ms / 1000) × $0.0000166667
Total cost = Request cost + Compute cost
```

**Example calculation (100,000 images through full pipeline):**

```
Python Pipeline (3 functions × 100k images = 300k invocations):
- Rotate:    avg_runtime = 245ms, memory = 512MB
- Resize:    avg_runtime = 387ms, memory = 512MB
- Greyscale: avg_runtime = 312ms, memory = 512MB

Request cost = (300,000 / 1,000,000) × $0.20 = $0.06
Compute cost =
  Rotate:    100k × (512/1024) × (245/1000) × 0.0000166667 = $0.20
  Resize:    100k × (512/1024) × (387/1000) × 0.0000166667 = $0.32
  Greyscale: 100k × (512/1024) × (312/1000) × 0.0000166667 = $0.26

Total cost = $0.06 + $0.20 + $0.32 + $0.26 = $0.84 per 100k images
```

---

### 5. Regional Comparison (Optional)

**Requirements:** Deploy same functions to multiple regions (e.g., us-west-2 vs us-east-1)

```sql
fields functionRegion, runtime, functionName
| filter @message like /INSPECTOR METRICS/
| parse @message '"functionRegion": "*"' as region
| parse @message '"runtime": *,' as runtime_ms
| parse @message '"functionName": "*"' as functionName
| stats
    avg(runtime_ms) as avg_runtime_ms,
    stddev(runtime_ms) as stddev_ms,
    count() as invocations
  by region, functionName
| sort region, functionName
```

**Example output:**
```
region       | functionName         | avg_runtime_ms | stddev_ms
-------------|---------------------|----------------|----------
us-west-2    | python_lambda_rotate| 245.3          | 12.4
us-east-1    | python_lambda_rotate| 238.7          | 11.8
```

---

### 6. CPU Architecture Comparison (Optional)

**Requirements:** Deploy same functions on x86_64 and arm64 (Graviton2)

```sql
fields cpuType, runtime, functionName
| filter @message like /INSPECTOR METRICS/
| parse @message '"cpuType": "*"' as cpu
| parse @message '"runtime": *,' as runtime_ms
| parse @message '"functionName": "*"' as functionName
| stats
    avg(runtime_ms) as avg_runtime_ms,
    stddev(runtime_ms) as stddev_ms,
    count() as invocations
  by cpu, functionName
| sort cpu, functionName
```

**Example output:**
```
cpu                           | functionName         | avg_runtime_ms
------------------------------|---------------------|----------------
Intel(R) Xeon(R) @ 2.50GHz   | python_lambda_rotate| 245.3
AWS Graviton2 Processor      | python_lambda_rotate| 198.5
```

**Analysis:** Graviton2 (ARM64) may be 15-20% faster and cheaper.

---

## How to Run CloudWatch Queries

### Using AWS Console

1. Go to **CloudWatch** → **Logs** → **Insights**
2. Select log groups for your Lambda functions:
   - `/aws/lambda/python_lambda_rotate`
   - `/aws/lambda/python_lambda_resize`
   - `/aws/lambda/python_lambda_greyscale`
   - (Plus Java and Node.js functions)
3. Set time range (e.g., Last 24 hours)
4. Paste query from above
5. Click **Run query**
6. Click **Export results** → **Download query results (CSV)**

### Using AWS CLI

```bash
# Run query and save to CSV
aws logs start-query \
    --log-group-names /aws/lambda/python_lambda_rotate \
                      /aws/lambda/python_lambda_resize \
                      /aws/lambda/python_lambda_greyscale \
    --start-time $(date -d '24 hours ago' +%s) \
    --end-time $(date +%s) \
    --query-string 'fields functionName, runtime | filter @message like /INSPECTOR METRICS/'

# Get results
aws logs get-query-results --query-id <query-id>
```

---

## Complete Testing Workflow

### Step 1: Generate Load

Upload test images to trigger your pipeline:

```bash
# Upload 100 test images
for i in {1..100}; do
    aws s3 cp test-image.jpg s3://your-bucket/input/test_${i}.jpg
done
```

### Step 2: Wait for Processing

Wait 2-3 minutes for all pipeline stages to complete.

### Step 3: Query CloudWatch

Run the queries above to extract metrics.

### Step 4: Export and Analyze

```python
import pandas as pd

# Load CloudWatch query results
df = pd.read_csv('cloudwatch_results.csv')

# Calculate CV
df['cv'] = (df['stddev_runtime_ms'] / df['avg_runtime_ms']) * 100

# Compare cold vs warm
cold = df[df['newcontainer'] == 1]
warm = df[df['newcontainer'] == 0]

print(f"Cold start avg: {cold['avg_runtime_ms'].mean():.2f} ms")
print(f"Warm start avg: {warm['avg_runtime_ms'].mean():.2f} ms")
print(f"Cold start overhead: {(cold['avg_runtime_ms'].mean() / warm['avg_runtime_ms'].mean() - 1) * 100:.1f}%")
```

---

## Summary: Available Metrics (Zero Additional Code)

| Metric | Status | How to Get |
|--------|--------|------------|
| **Runtime statistics** | ✅ Ready | Query #1 |
| **Cold vs warm starts** | ✅ Ready | Query #2 |
| **Pipeline latency** | ✅ Ready | Query #3 |
| **Cost estimates** | ✅ Ready | Query #4 + formula |
| **Regional comparison** | ✅ Ready* | Query #5 (*requires multi-region deployment) |
| **CPU architecture** | ✅ Ready* | Query #6 (*requires x86+ARM deployment) |

All queries work with your existing code - just add the 2 lines per function that were already added!

---

## Optional: Deploy to Multiple Regions/Architectures

### Deploy to us-east-1

```bash
cd python_deployment/python_lambda_rotate
./deploy.sh --region us-east-1

cd ../python_lambda_resize
./deploy.sh --region us-east-1

cd ../python_lambda_greyscale
./deploy.sh --region us-east-1
```

### Deploy on ARM64/Graviton2

Update `deploy/config.json`:
```json
{
  "lambdaArchitecture": "arm64"
}
```

Then redeploy.

---

## Next Steps

1. ✅ Code changes complete (2 lines per function already added)
2. ✅ Upload test images to generate metrics
3. ✅ Run CloudWatch Logs Insights queries
4. ✅ Export results as CSV
5. ✅ Calculate derived metrics (CV, costs)
6. ✅ Generate tables and charts for your report

You now have everything needed for comprehensive performance analysis using only CloudWatch!
