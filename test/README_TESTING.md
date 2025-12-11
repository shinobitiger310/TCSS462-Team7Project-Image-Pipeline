# Testing Guide - One Command to Compare All Languages

## What the Test Does

The `run_all_experiments.sh` script will:

1. **Test all 9 Lambda functions** (3 languages × 3 functions)
   - Python: rotate, resize, greyscale
   - Java: rotate, resize, grayscale
   - Node.js: rotate, resize, greyscale

2. **Run 50 times per function** (using test payloads, not real images)
   - Total: 450 function invocations
   - Takes about 30-40 minutes

3. **Collect performance metrics**
   - Runtime, latency, cold starts
   - CPU info, container reuse
   - Saves individual CSV files for each function

4. **Generate ONE comparison report**
   - Automatically combines all results
   - Shows average runtime for each language
   - Saved as `comparison_summary.txt`

## How to Run

### Step 1: Make sure functions are deployed

```bash
./check_deployed_functions.sh
```

You should see all 9 functions deployed.

### Step 2: Run the complete test

```bash
./run_all_experiments.sh
```

This will:
- Run 450 total function calls (9 functions × 50 runs each)
- Take ~30-40 minutes
- Show progress for each language

### Step 3: View the comparison report

```bash
cat results_*/comparison_summary.txt
```

## What You'll Get

### Output Structure
```
results_20241209_150322/
├── python_rotate/
│   └── language_comparison_zAll.csv
├── python_resize/
│   └── language_comparison_zAll.csv
├── python_greyscale/
│   └── language_comparison_zAll.csv
├── java_rotate/
│   └── language_comparison_zAll.csv
├── java_resize/
│   └── language_comparison_zAll.csv
├── java_grayscale/
│   └── language_comparison_zAll.csv
├── nodejs_rotate/
│   └── language_comparison_zAll.csv
├── nodejs_resize/
│   └── language_comparison_zAll.csv
├── nodejs_greyscale/
│   └── language_comparison_zAll.csv
└── comparison_summary.txt  ← ONE UNIFIED REPORT
```

### Sample Report Output
```
====================================================================
  Multi-Language Comparison Report
====================================================================

Average Runtime (ms)
--------------------------------------------------------------------
Language     | Rotate   | Resize   | Grayscale  | Total
--------------------------------------------------------------------
Python       |  245.3ms |  387.2ms |   312.4ms |   944.9ms
Java         |  312.7ms |  425.8ms |   348.9ms |  1087.4ms
Node.js      |  198.5ms |  356.9ms |   289.3ms |   844.7ms

====================================================================
Detailed Statistics
====================================================================

PYTHON Details:
--------------------------------------------------

  Rotate:
    Mean:   245.30 ms
    Std:    12.40 ms
    Median: 243.50 ms
    Min:    230.00 ms
    Max:    275.00 ms
    Runs:   50

  Resize:
    Mean:   387.20 ms
    Std:    22.10 ms
    ...
```

## Using the Results for Your Report

### For Methodology Section
"We tested each implementation 50 times using the SAAF framework to measure execution time, latency, and cold start frequency. The test used identical logic across all three languages to ensure fair comparison."

### For Results Section
Use the comparison_summary.txt to create tables showing:
- Average runtime per function
- Total pipeline time per language
- Standard deviation (variance in performance)

### For Analysis
- Which language is fastest overall?
- Which has most consistent performance (lowest std dev)?
- Cold start impact varies by language?

## Quick Test (3 runs only)

If you want to test quickly before running the full 50 runs:

```bash
./quick_test.sh
```

This tests Python rotate function 3 times to verify everything works.

## What If I Want Real Image Processing?

The current test uses test payloads for performance measurement. If you want to actually process images:

```bash
cd ../python_deployment
./test_python_all.sh
```

This will process a real image through the Python pipeline and download the result.

## Troubleshooting

### "Function not found"
Run `./check_deployed_functions.sh` to see which functions are missing, then deploy them.

### "Can't parse response"
The fix should already be applied. Check that `test/tools/experiment_caller.py` line 118 uses `json.loads()`.

### Empty CSV files
Check that runs completed successfully. Look for "Run X.Y successful" messages.

## Summary

✅ **One script**: `./run_all_experiments.sh`
✅ **All 3 languages tested**: Python, Java, Node.js
✅ **50 runs per function**: Statistical significance
✅ **One comparison report**: `comparison_summary.txt`
✅ **Takes ~30-40 minutes**: Automated, hands-off

This gives you comprehensive, publication-ready performance comparison data!

---

# Pipeline Testing (Tutorial 10 - FaaS Runner Pipelines)

## What are Pipelines?

The dual-mode functions now support **synchronous pipeline execution** where output from one function becomes input to the next:

```
rotate → resize → greyscale (all in one chain)
```

Benefits:
- Measures end-to-end pipeline latency
- Tests payload passing between functions
- Compares language performance in multi-stage workflows

## Pipeline Experiment Files

Created pipeline experiments in `test/experiments/`:

1. **pipeline_python.json** - Python pipeline (rotate → resize → greyscale)
2. **pipeline_java.json** - Java pipeline (rotate → resize → grayscale)
3. **pipeline_nodejs.json** - Node.js pipeline (rotate → resize → greyscale)
4. **pipeline_all_languages.json** - All languages comparison

Key settings:
- `passPayloads: true` - Passes image_data between stages
- `transitions: {}` - Linear pipeline flow (default)
- Uses base64 encoded image data between stages

## How to Run Pipeline Tests

### Test Python Pipeline

```bash
python3 faas_runner.py \
  -f ./functions/python_rotate.json \
     ./functions/python_resize.json \
     ./functions/python_greyscale.json \
  -e ./experiments/pipeline_python.json \
  -o ./history/pipeline_python
```

### Test Java Pipeline

```bash
python3 faas_runner.py \
  -f ./functions/java_rotate.json \
     ./functions/java_resize.json \
     ./functions/java_grayscale.json \
  -e ./experiments/pipeline_java.json \
  -o ./history/pipeline_java
```

### Test Node.js Pipeline

```bash
python3 faas_runner.py \
  -f ./functions/nodejs_rotate.json \
     ./functions/nodejs_resize.json \
     ./functions/nodejs_greyscale.json \
  -e ./experiments/pipeline_nodejs.json \
  -o ./history/pipeline_nodejs
```

### Compare All Languages (Pipeline Mode)

```bash
python3 faas_runner.py \
  -f ./functions/python_rotate.json \
     ./functions/python_resize.json \
     ./functions/python_greyscale.json \
     ./functions/java_rotate.json \
     ./functions/java_resize.json \
     ./functions/java_grayscale.json \
     ./functions/nodejs_rotate.json \
     ./functions/nodejs_resize.json \
     ./functions/nodejs_greyscale.json \
  -e ./experiments/pipeline_all_languages.json \
  -o ./history/pipeline_comparison
```

## What Pipeline Tests Measure

Pipeline experiments measure:
- **End-to-end latency**: Total time for all 3 stages
- **Per-stage runtime**: Time for rotate, resize, greyscale
- **Payload passing overhead**: Cost of base64 encoding/decoding
- **Container reuse**: How often containers are reused across stages
- **Total pipeline throughput**: Runs/second for complete pipeline

## Dual-Mode Function Architecture

All 9 functions now support TWO invocation modes:

### MODE 1: S3 Event Trigger (Original)
- Triggered by S3 PUT events
- Reads from S3, processes, writes to S3
- Asynchronous pipeline via S3

### MODE 2: Direct Invocation (FaaS Runner Pipeline)
- Invoked with image_data in payload
- Processes and returns result
- Synchronous pipeline via payload passing

The function automatically detects which mode to use based on event structure:
- **S3 Event**: Contains `Records` array
- **Direct Invocation**: Contains `image_data` or `s3_bucket`/`s3_key`

## Pipeline vs Individual Function Testing

**Individual Testing** (existing):
- Tests each function independently
- 50 runs per function = 450 total calls
- Measures isolated function performance

**Pipeline Testing** (new):
- Tests entire workflow (rotate → resize → greyscale)
- 10 runs × 3 functions = 30 calls per pipeline
- Measures end-to-end workflow performance
- Shows impact of payload passing

## Expected Pipeline Results

Pipeline latency should be approximately:
```
Total Pipeline Time ≈ Rotate + Resize + Greyscale + Overhead

Example:
Python:   245ms + 387ms + 312ms + ~50ms = ~994ms
Java:     313ms + 426ms + 349ms + ~50ms = ~1138ms
Node.js:  199ms + 357ms + 289ms + ~50ms = ~895ms
```

The overhead includes:
- Base64 encoding/decoding between stages
- Network latency for function invocations
- Lambda startup time if new containers needed
