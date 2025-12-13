# Complete Pipeline Performance Test

Automated test script that runs all three language implementations and generates a comprehensive performance report.

## Quick Start

```bash
cd test
./run_complete_pipeline_test.sh 50
```

This will:
1. ✅ Upload 50 test images to S3
2. ✅ Trigger Python, Java, and Node.js pipelines
3. ✅ Wait for processing to complete
4. ✅ Query CloudWatch for all metrics
5. ✅ Generate comprehensive markdown report
6. ✅ Clean up test files

**Total time:** ~5-6 minutes

## What You Get

### Generated Report Structure

```
test/reports/complete_test_YYYYMMDD_HHMMSS/
├── PERFORMANCE_REPORT.md          ← Main report (ready for your paper!)
├── runtime_stats.json              ← Raw CloudWatch data
├── cold_warm_stats.json            ← Cold vs warm metrics
├── pipeline_latency.json           ← End-to-end latency data
└── cost_data.json                  ← Cost calculation data
```

### Report Contents

The `PERFORMANCE_REPORT.md` includes:

**1. Runtime Statistics per Function**
- Average runtime (ms)
- Standard deviation (ms)
- Coefficient of Variation (CV %)
- Min, Max, P95, P99 runtimes
- Number of invocations

Example output:
```
| Function                | Avg (ms) | Std Dev | CV (%) | P95 (ms) |
|------------------------|----------|---------|--------|----------|
| python_lambda_greyscale| 312.4    | 15.2    | 4.87   | 338.2    |
| python_lambda_resize   | 387.2    | 22.1    | 5.71   | 425.8    |
| python_lambda_rotate   | 245.3    | 12.4    | 5.05   | 267.1    |
```

**2. Cold Start vs. Warm Start Analysis**
- Performance comparison
- Count of each type
- Standard deviation

Example output:
```
| Function                | Type       | Avg Runtime (ms) | Count |
|------------------------|------------|------------------|-------|
| python_lambda_rotate   | Cold Start | 892.7            | 5     |
| python_lambda_rotate   | Warm Start | 210.3            | 45    |
```

**3. End-to-End Pipeline Latency**
- Average total time from rotate → greyscale
- Standard deviation
- Min and max latencies

Example output:
```
Average Pipeline Latency: 2.34 seconds
Standard Deviation: 0.42 seconds
Min Latency: 1.82 seconds
Max Latency: 4.91 seconds
```

**4. Cost Estimates**
- Cost breakdown per function
- Projected cost for 100,000 images
- Request cost + Compute cost

Example output:
```
python_lambda_rotate:
  Request cost: $0.0200
  Compute cost: $0.2044
  Total: $0.2244

Total Cost for 100k images: $0.84
```

---

## Usage

### Basic Test (50 images)

```bash
./run_complete_pipeline_test.sh
```

### Custom Number of Images

```bash
./run_complete_pipeline_test.sh 100   # Test with 100 images
./run_complete_pipeline_test.sh 10    # Quick test with 10 images
```

### View Report

```bash
# Find latest report
LATEST=$(ls -td reports/complete_test_* | head -1)

# View in terminal
cat $LATEST/PERFORMANCE_REPORT.md

# Open in editor
code $LATEST/PERFORMANCE_REPORT.md
```

---

## Requirements

**AWS Resources:**
- S3 bucket configured: `tcss462-image-pipeline-bdiep-group7-local`
- All 9 Lambda functions deployed:
  - `python_lambda_rotate`, `python_lambda_resize`, `python_lambda_greyscale`
  - `java_lambda_rotate`, `java_lambda_resize`, `java_lambda_grayscale`
  - `nodejs_lambda_rotate`, `nodejs_lambda_resize`, `nodejs_lambda_greyscale`

**Local Tools:**
- AWS CLI configured with credentials
- Python 3.x
- Bash

**Test Image:**
- Located at: `./Kirmizi_Pistachio/kirmizi 1.jpg`

---

## How It Works

### Step 1: Upload Test Images (10-30s)
```bash
for i in 1..50; do
    aws s3 cp test.jpg s3://bucket/input/test_${i}.jpg
done
```

### Step 2: Wait for Processing (180s)
- Allows time for all 3 pipeline stages to complete
- S3 events trigger: rotate → resize → greyscale

### Step 3: Query CloudWatch (30-60s)
Runs 4 CloudWatch Logs Insights queries:
1. Runtime statistics per function
2. Cold vs warm start comparison
3. Pipeline latency (image correlation)
4. Cost calculation data

### Step 4: Generate Report (5s)
- Parses CloudWatch JSON results
- Calculates derived metrics (CV, costs)
- Generates markdown report

### Step 5: Cleanup (10s)
- Removes test images from S3
- Keeps report files locally

---

## Troubleshooting

### "Test image not found"
```bash
# Check image path
ls -lh ./Kirmizi_Pistachio/kirmizi\ 1.jpg

# Or update TEST_IMAGE variable in script
```

### "Function not found" or "Access Denied"
```bash
# Verify Lambda functions exist
aws lambda list-functions --query 'Functions[?contains(FunctionName, `lambda_rotate`)].FunctionName'

# Check AWS credentials
aws sts get-caller-identity
```

### "No data in CloudWatch"
- Functions may not have been invoked
- Check S3 event triggers are configured
- Increase wait time in script (change WAIT_TIME=180 to WAIT_TIME=300)

### Empty or incomplete report
- Not enough time for processing - increase WAIT_TIME
- CloudWatch query returned no results - check log groups exist
- Functions failed - check CloudWatch logs for errors

---

## Customization

### Change S3 Bucket

Edit script line 13:
```bash
S3_BUCKET="your-bucket-name-here"
```

### Change Test Image

Edit script line 14:
```bash
TEST_IMAGE="./path/to/your/image.jpg"
```

### Add More Queries

Add after line 195:
```bash
QUERY_5='your CloudWatch Logs Insights query here'
run_cloudwatch_query "Query Name" "$ALL_LOGS" "$QUERY_5" "$REPORT_DIR/query5.json"
```

### Modify Report Format

Edit the Python script section (starting line 223) to customize the markdown report format.

---

## Example Workflow for Research Paper

**1. Run comprehensive test:**
```bash
./run_complete_pipeline_test.sh 100
```

**2. Copy report to your paper directory:**
```bash
cp reports/complete_test_*/PERFORMANCE_REPORT.md ~/my-paper/results/
```

**3. Extract key metrics for tables:**
```bash
# Runtime comparison table
grep "| python_lambda" reports/complete_test_*/PERFORMANCE_REPORT.md

# Cold start overhead calculation
grep "Cold Start\|Warm Start" reports/complete_test_*/PERFORMANCE_REPORT.md
```

**4. Create visualizations from raw data:**
```python
import json
import pandas as pd
import matplotlib.pyplot as plt

# Load runtime data
with open('reports/complete_test_*/runtime_stats.json') as f:
    data = json.load(f)

# Create bar chart
df = pd.DataFrame(data['results'])
df.plot(kind='bar', x='functionName', y='avg_runtime_ms')
plt.savefig('runtime_comparison.png')
```

---

## Tips for Best Results

**For Statistical Significance:**
- Use at least 50 images (100+ recommended)
- Run test multiple times and average results
- Test at different times of day to capture variability

**For Cold Start Testing:**
- Wait >5 minutes between tests for cold starts
- Or manually set concurrency to 0 to force cold starts

**For Cost Accuracy:**
- Run with realistic image sizes
- Test with varied image dimensions
- Consider data transfer costs separately

**For Pipeline Latency:**
- Ensure all functions use same S3 bucket
- Check S3 event notifications are configured correctly
- Monitor S3 for bottlenecks

---

## Output Files Explained

**PERFORMANCE_REPORT.md**
- Human-readable markdown report
- Ready to copy into research paper
- Includes all calculated metrics

**runtime_stats.json**
- Raw CloudWatch query results
- Contains all function invocations
- Use for custom analysis

**cold_warm_stats.json**
- Breakdown by container reuse
- Identifies cold start overhead

**pipeline_latency.json**
- End-to-end timing per image
- Use to analyze outliers

**cost_data.json**
- Memory and runtime for cost calculation
- Extrapolate to any batch size

---

## Next Steps After Testing

1. ✅ Review PERFORMANCE_REPORT.md
2. ✅ Identify performance bottlenecks (which function is slowest?)
3. ✅ Analyze cold start impact (how much overhead?)
4. ✅ Calculate cost at scale (affordable for production?)
5. ✅ Compare languages (Python vs Java vs Node.js)
6. ✅ Create visualizations from raw JSON data
7. ✅ Write analysis section for research paper

All metrics required for your report are now automated!
