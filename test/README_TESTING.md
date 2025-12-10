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
