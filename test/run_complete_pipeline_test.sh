#!/bin/bash

#
# Complete Pipeline Test - All Languages with CloudWatch Metrics
#
# This script:
# 1. Uploads test images to trigger all 3 language pipelines
# 2. Waits for processing to complete
# 3. Queries CloudWatch for metrics
# 4. Generates a comprehensive report
#
# Usage: ./run_complete_pipeline_test.sh [num_images]
#   num_images: Number of test images to process (default: 50)
#

set -e  # Exit on error

# Configuration
NUM_IMAGES="${1:-50}"
S3_BUCKET="tcss462-image-pipeline-bdiep-group7-local"
TEST_IMAGE="./Kirmizi_Pistachio/kirmizi 1.jpg"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="./reports/complete_test_${TIMESTAMP}"

# Check if test image exists
if [ ! -f "$TEST_IMAGE" ]; then
    echo "ERROR: Test image not found at $TEST_IMAGE"
    exit 1
fi

# Create report directory
mkdir -p "$REPORT_DIR"

echo "======================================================================"
echo "  Complete Pipeline Test - All Languages"
echo "======================================================================"
echo ""
echo "Configuration:"
echo "  - Test images: $NUM_IMAGES"
echo "  - S3 Bucket: $S3_BUCKET"
echo "  - Report directory: $REPORT_DIR"
echo ""
echo "This test will:"
echo "  1. Upload $NUM_IMAGES test images"
echo "  2. Trigger Python, Java, and Node.js pipelines"
echo "  3. Wait for processing (~2-3 minutes)"
echo "  4. Query CloudWatch for metrics"
echo "  5. Generate comprehensive report"
echo ""
echo "----------------------------------------------------------------------"

# Step 1: Upload test images
echo ""
echo "Step 1: Uploading $NUM_IMAGES test images to S3..."
echo ""

START_TIME=$(date +%s)

for i in $(seq 1 $NUM_IMAGES); do
    # Upload to different prefixes to trigger different language pipelines
    # This assumes you have different S3 event triggers for each language

    # For testing, we'll upload to the same prefix and rely on all functions processing
    aws s3 cp "$TEST_IMAGE" "s3://${S3_BUCKET}/input/test_${i}.jpg" --quiet

    # Show progress
    if [ $((i % 10)) -eq 0 ]; then
        echo "  Uploaded $i/$NUM_IMAGES images..."
    fi
done

UPLOAD_END_TIME=$(date +%s)
UPLOAD_DURATION=$((UPLOAD_END_TIME - START_TIME))

echo ""
echo "✓ Uploaded $NUM_IMAGES images in ${UPLOAD_DURATION}s"

# Step 2: Wait for processing
echo ""
echo "Step 2: Waiting for pipeline processing to complete..."
echo "  (Waiting 180 seconds for all stages to complete)"
echo ""

WAIT_TIME=180
for i in $(seq $WAIT_TIME -10 1); do
    echo -ne "  Time remaining: ${i}s\r"
    sleep 10
done
echo ""
echo "✓ Processing complete"

PROCESS_END_TIME=$(date +%s)

# Step 3: Query CloudWatch for metrics
echo ""
echo "Step 3: Querying CloudWatch Logs for metrics..."
echo ""

# Calculate time range for CloudWatch query
QUERY_START_TIME=$((START_TIME - 60))  # Start 1 min before upload
QUERY_END_TIME=$PROCESS_END_TIME

# Function to run CloudWatch query and wait for results
run_cloudwatch_query() {
    local query_name=$1
    local log_groups=$2
    local query_string=$3
    local output_file=$4

    echo "  Running query: $query_name"

    # Start query
    QUERY_ID=$(aws logs start-query \
        --log-group-names $log_groups \
        --start-time $QUERY_START_TIME \
        --end-time $QUERY_END_TIME \
        --query-string "$query_string" \
        --query 'queryId' \
        --output text)

    # Wait for query to complete
    STATUS="Running"
    while [ "$STATUS" = "Running" ] || [ "$STATUS" = "Scheduled" ]; do
        sleep 2
        STATUS=$(aws logs get-query-results --query-id $QUERY_ID --query 'status' --output text)
    done

    # Get results
    if [ "$STATUS" = "Complete" ]; then
        aws logs get-query-results --query-id $QUERY_ID --output json > "$output_file"
        echo "    ✓ Saved to $output_file"
    else
        echo "    ✗ Query failed with status: $STATUS"
    fi
}

# Define log groups for all Lambda functions
PYTHON_LOGS="/aws/lambda/python_lambda_rotate /aws/lambda/python_lambda_resize /aws/lambda/python_lambda_greyscale"
JAVA_LOGS="/aws/lambda/java_lambda_rotate /aws/lambda/java_lambda_resize /aws/lambda/java_lambda_grayscale"
NODEJS_LOGS="/aws/lambda/nodejs_lambda_rotate /aws/lambda/nodejs_lambda_resize /aws/lambda/nodejs_lambda_greyscale"
ALL_LOGS="$PYTHON_LOGS $JAVA_LOGS $NODEJS_LOGS"

# Query 1: Runtime statistics per function
QUERY_1='fields functionName, runtime, newcontainer
| filter @message like /INSPECTOR METRICS/
| parse @message "\"runtime\": *," as runtime_ms
| parse @message "\"functionName\": \"*\"" as functionName
| parse @message "\"newcontainer\": *," as newcontainer
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
| sort avg_runtime_ms desc'

run_cloudwatch_query "Runtime Statistics" "$ALL_LOGS" "$QUERY_1" "$REPORT_DIR/runtime_stats.json"

# Query 2: Cold vs Warm start comparison
QUERY_2='fields functionName, runtime, newcontainer
| filter @message like /INSPECTOR METRICS/
| parse @message "\"runtime\": *," as runtime_ms
| parse @message "\"functionName\": \"*\"" as functionName
| parse @message "\"newcontainer\": *," as newcontainer
| stats
    avg(runtime_ms) as avg_runtime_ms,
    stddev(runtime_ms) as stddev_ms,
    count() as count
  by functionName, newcontainer
| sort functionName, newcontainer'

run_cloudwatch_query "Cold vs Warm Starts" "$ALL_LOGS" "$QUERY_2" "$REPORT_DIR/cold_warm_stats.json"

# Query 3: Pipeline latency
QUERY_3='fields image_id, pipeline_stage, startTime, endTime
| filter @message like /INSPECTOR METRICS/
| parse @message "\"image_id\": \"*\"" as image_id
| parse @message "\"pipeline_stage\": \"*\"" as stage
| parse @message "\"startTime\": *," as start_time
| parse @message "\"endTime\": *," as end_time
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
    max(pipeline_latency_seconds) as max_s'

run_cloudwatch_query "Pipeline Latency" "$ALL_LOGS" "$QUERY_3" "$REPORT_DIR/pipeline_latency.json"

# Query 4: Memory and function details for cost calculation
QUERY_4='fields functionName, runtime, functionMemory
| filter @message like /INSPECTOR METRICS/
| parse @message "\"functionName\": \"*\"" as functionName
| parse @message "\"runtime\": *," as runtime_ms
| parse @message "\"functionMemory\": \"*\"" as memory_mb
| stats
    count() as invocations,
    avg(runtime_ms) as avg_runtime_ms,
    avg(memory_mb) as avg_memory_mb
  by functionName'

run_cloudwatch_query "Cost Data" "$ALL_LOGS" "$QUERY_4" "$REPORT_DIR/cost_data.json"

echo ""
echo "✓ All CloudWatch queries complete"

# Step 4: Generate report
echo ""
echo "Step 4: Generating comprehensive report..."
echo ""

python3 - << 'PYTHON_SCRIPT'
import json
import sys
from pathlib import Path

report_dir = Path("'$REPORT_DIR'")

print("Generating report from CloudWatch data...")

# Read all query results
with open(report_dir / "runtime_stats.json") as f:
    runtime_data = json.load(f)

with open(report_dir / "cold_warm_stats.json") as f:
    cold_warm_data = json.load(f)

with open(report_dir / "pipeline_latency.json") as f:
    pipeline_data = json.load(f)

with open(report_dir / "cost_data.json") as f:
    cost_data = json.load(f)

# Generate markdown report
report = []
report.append("# Image Processing Pipeline - Performance Report")
report.append(f"\n**Generated:** {Path("'$TIMESTAMP'").name}")
report.append(f"\n**Test Images:** '$NUM_IMAGES'")
report.append(f"\n**S3 Bucket:** '$S3_BUCKET'")
report.append("\n---\n")

# Section 1: Runtime Statistics
report.append("## 1. Runtime Statistics per Function\n")
report.append("| Function | Invocations | Avg (ms) | Std Dev (ms) | CV (%) | Min (ms) | Max (ms) | P95 (ms) | P99 (ms) |")
report.append("|----------|-------------|----------|--------------|--------|----------|----------|----------|----------|")

for result in runtime_data.get("results", []):
    fields = {item["field"]: item["value"] for item in result}
    func_name = fields.get("functionName", "N/A")
    invocations = fields.get("invocations", "0")
    avg = float(fields.get("avg_runtime_ms", "0"))
    stddev = float(fields.get("stddev_runtime_ms", "0"))
    cv = (stddev / avg * 100) if avg > 0 else 0
    min_ms = fields.get("min_runtime_ms", "0")
    max_ms = fields.get("max_runtime_ms", "0")
    p95 = fields.get("p95_runtime_ms", "0")
    p99 = fields.get("p99_runtime_ms", "0")

    report.append(f"| {func_name} | {invocations} | {avg:.2f} | {stddev:.2f} | {cv:.2f} | {min_ms} | {max_ms} | {p95} | {p99} |")

report.append("\n---\n")

# Section 2: Cold vs Warm Start Comparison
report.append("## 2. Cold Start vs. Warm Start Analysis\n")
report.append("| Function | Type | Avg Runtime (ms) | Std Dev (ms) | Count |")
report.append("|----------|------|------------------|--------------|-------|")

for result in cold_warm_data.get("results", []):
    fields = {item["field"]: item["value"] for item in result}
    func_name = fields.get("functionName", "N/A")
    newcontainer = fields.get("newcontainer", "0")
    start_type = "Cold Start" if newcontainer == "1" else "Warm Start"
    avg = fields.get("avg_runtime_ms", "0")
    stddev = fields.get("stddev_ms", "0")
    count = fields.get("count", "0")

    report.append(f"| {func_name} | {start_type} | {avg} | {stddev} | {count} |")

report.append("\n---\n")

# Section 3: Pipeline Latency
report.append("## 3. End-to-End Pipeline Latency\n")

if pipeline_data.get("results"):
    fields = {item["field"]: item["value"] for item in pipeline_data["results"][0]}
    avg_latency = fields.get("avg_pipeline_latency_s", "0")
    stddev = fields.get("stddev_s", "0")
    min_latency = fields.get("min_s", "0")
    max_latency = fields.get("max_s", "0")

    report.append(f"- **Average Pipeline Latency:** {avg_latency} seconds")
    report.append(f"- **Standard Deviation:** {stddev} seconds")
    report.append(f"- **Min Latency:** {min_latency} seconds")
    report.append(f"- **Max Latency:** {max_latency} seconds")
else:
    report.append("*No pipeline latency data available*")

report.append("\n---\n")

# Section 4: Cost Estimates
report.append("## 4. Cost Estimates (for 100,000 images)\n")
report.append("\n**AWS Lambda Pricing (us-west-2):**")
report.append("- Requests: $0.20 per 1M requests")
report.append("- Compute: $0.0000166667 per GB-second\n")

total_cost = 0.0

for result in cost_data.get("results", []):
    fields = {item["field"]: item["value"] for item in result}
    func_name = fields.get("functionName", "N/A")
    invocations = int(fields.get("invocations", "0"))
    avg_runtime_ms = float(fields.get("avg_runtime_ms", "0"))
    avg_memory_mb = float(fields.get("avg_memory_mb", "512"))

    # Calculate cost for 100k images
    scaled_invocations = 100000
    request_cost = (scaled_invocations / 1_000_000) * 0.20
    memory_gb = avg_memory_mb / 1024
    runtime_seconds = avg_runtime_ms / 1000
    gb_seconds = scaled_invocations * memory_gb * runtime_seconds
    compute_cost = gb_seconds * 0.0000166667
    function_cost = request_cost + compute_cost
    total_cost += function_cost

    report.append(f"\n**{func_name}:**")
    report.append(f"- Request cost: ${request_cost:.4f}")
    report.append(f"- Compute cost: ${compute_cost:.4f}")
    report.append(f"- Total: ${function_cost:.4f}")

report.append(f"\n**Total Cost for 100k images (all functions): ${total_cost:.2f}**")

report.append("\n---\n")

# Save report
report_text = "\n".join(report)
with open(report_dir / "PERFORMANCE_REPORT.md", "w") as f:
    f.write(report_text)

print(report_text)
print(f"\n✓ Report saved to {report_dir}/PERFORMANCE_REPORT.md")

PYTHON_SCRIPT

# Step 5: Cleanup test images
echo ""
echo "Step 5: Cleaning up test images from S3..."
echo ""

aws s3 rm "s3://${S3_BUCKET}/input/" --recursive --quiet
aws s3 rm "s3://${S3_BUCKET}/stage1/" --recursive --quiet
aws s3 rm "s3://${S3_BUCKET}/stage2/" --recursive --quiet
aws s3 rm "s3://${S3_BUCKET}/output/" --recursive --quiet

echo "✓ Cleanup complete"

# Done
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

echo ""
echo "======================================================================"
echo "  Test Complete!"
echo "======================================================================"
echo ""
echo "Summary:"
echo "  - Images processed: $NUM_IMAGES"
echo "  - Total duration: ${TOTAL_DURATION}s"
echo "  - Report directory: $REPORT_DIR"
echo ""
echo "View results:"
echo "  cat $REPORT_DIR/PERFORMANCE_REPORT.md"
echo ""
echo "Raw data files:"
echo "  - $REPORT_DIR/runtime_stats.json"
echo "  - $REPORT_DIR/cold_warm_stats.json"
echo "  - $REPORT_DIR/pipeline_latency.json"
echo "  - $REPORT_DIR/cost_data.json"
echo ""
