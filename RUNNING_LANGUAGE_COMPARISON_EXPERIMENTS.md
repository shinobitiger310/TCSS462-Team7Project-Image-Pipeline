# Running Language Comparison Experiments - Complete Guide

## Overview

This guide shows you how to run automated performance experiments comparing Java, Node.js, and Python implementations of your image processing functions using the fixed faas_runner.

## Prerequisites

✅ faas_runner parsing is now fixed (json.loads instead of ast.literal_eval)
✅ All Lambda functions are deployed to AWS
✅ AWS CLI is configured with proper credentials

## Step 1: Create Function Definition Files

Create JSON files in `test/functions/` for each Lambda function:

### Python Functions

**test/functions/python_rotate.json**
```json
{
    "function": "python_lambda_rotate",
    "platform": "AWS Lambda",
    "source": "../python_deployment/python_lambda_rotate",
    "endpoint": "python_lambda_rotate"
}
```

**test/functions/python_resize.json**
```json
{
    "function": "python_lambda_resize",
    "platform": "AWS Lambda",
    "source": "../python_deployment/python_lambda_resize",
    "endpoint": "python_lambda_resize"
}
```

**test/functions/python_greyscale.json**
```json
{
    "function": "python_lambda_greyscale",
    "platform": "AWS Lambda",
    "source": "../python_deployment/python_lambda_greyscale",
    "endpoint": "python_lambda_greyscale"
}
```

### Node.js Functions

**test/functions/nodejs_rotate.json**
```json
{
    "function": "nodejs_lambda_rotate",
    "platform": "AWS Lambda",
    "source": "../nodejs_template",
    "endpoint": "nodejs_lambda_rotate"
}
```

(Note: You'll need to check if Node.js versions are deployed. The template shows `nodejs_lambda_rotate` as the function name)

### Java Functions

**test/functions/java_rotate.json**
```json
{
    "function": "java_lambda_rotate",
    "platform": "AWS Lambda",
    "source": "../java_template",
    "endpoint": "java_lambda_rotate"
}
```

**test/functions/java_resize.json**
```json
{
    "function": "java_lambda_resize",
    "platform": "AWS Lambda",
    "source": "../java_template",
    "endpoint": "java_lambda_resize"
}
```

**test/functions/java_greyscale.json**
```json
{
    "function": "java_lambda_grayscale",
    "platform": "AWS Lambda",
    "source": "../java_template",
    "endpoint": "java_lambda_grayscale"
}
```

## Step 2: Create Experiment Configuration

**test/experiments/language_comparison.json**
```json
{
    "callWithCLI": true,
    "callAsync": false,
    "memorySettings": [],

    "runs": 50,
    "threads": 10,
    "iterations": 1,
    "sleepTime": 2,
    "randomSeed": 42,

    "outputGroups": [
        "uuid",
        "newcontainer",
        "cpuType",
        "vmID",
        "zAll"
    ],
    "outputRawOfGroup": ["cpuType"],
    "showAsList": ["cpuType", "containerID", "vmID"],
    "showAsSum": ["newcontainer"],

    "ignoreFromAll": ["zAll", "lang", "version", "linuxVersion", "platform", "hostname"],
    "ignoreFromGroups": ["1_run_id", "2_thread_id", "cpuIdle", "cpuIowait"],

    "invalidators": {},
    "removeDuplicateContainers": false,

    "openCSV": true,
    "combineSheets": false,
    "warmupBuffer": 5,
    "experimentName": "language_comparison"
}
```

## Step 3: Quick Test (3 runs to verify everything works)

**test/experiments/quick_test.json**
```json
{
    "callWithCLI": true,
    "callAsync": false,
    "runs": 3,
    "threads": 1,
    "iterations": 1,
    "sleepTime": 1,
    "experimentName": "quick_test"
}
```

### Run Quick Test
```bash
cd test

# Test Python
./faas_runner.py -f functions/python_rotate.json -e experiments/quick_test.json -o ./quick_results

# Test Java (if deployed)
./faas_runner.py -f functions/java_rotate.json -e experiments/quick_test.json -o ./quick_results

# Test Node.js (if deployed)
./faas_runner.py -f functions/nodejs_rotate.json -e experiments/quick_test.json -o ./quick_results
```

**Expected Output:**
```
Run 0.0 successful.
Run 0.1 successful.
Run 0.2 successful.
```

If you see "Failed with exception" or "can't parse", check:
1. Function is deployed (`aws lambda list-functions`)
2. Function name matches in config.json
3. Inspector is returning metrics properly

## Step 4: Run Full Comparison Experiments

Create a script to run all experiments systematically:

**test/run_all_experiments.sh**
```bash
#!/bin/bash

# Language Comparison Experiments
# Runs all three image processing functions for each language

EXPERIMENT="experiments/language_comparison.json"
OUTPUT_DIR="./results_$(date +%Y%m%d_%H%M%S)"

mkdir -p $OUTPUT_DIR

echo "=========================================="
echo "  Running Language Comparison Experiments"
echo "=========================================="
echo ""
echo "Output directory: $OUTPUT_DIR"
echo ""

# Python Experiments
echo "===== PYTHON EXPERIMENTS ====="
echo "Running Python Rotate..."
./faas_runner.py -f functions/python_rotate.json -e $EXPERIMENT -o "$OUTPUT_DIR/python_rotate"

echo ""
echo "Running Python Resize..."
./faas_runner.py -f functions/python_resize.json -e $EXPERIMENT -o "$OUTPUT_DIR/python_resize"

echo ""
echo "Running Python Greyscale..."
./faas_runner.py -f functions/python_greyscale.json -e $EXPERIMENT -o "$OUTPUT_DIR/python_greyscale"

# Java Experiments (uncomment if Java functions are deployed)
# echo ""
# echo "===== JAVA EXPERIMENTS ====="
# echo "Running Java Rotate..."
# ./faas_runner.py -f functions/java_rotate.json -e $EXPERIMENT -o "$OUTPUT_DIR/java_rotate"
#
# echo ""
# echo "Running Java Resize..."
# ./faas_runner.py -f functions/java_resize.json -e $EXPERIMENT -o "$OUTPUT_DIR/java_resize"
#
# echo ""
# echo "Running Java Greyscale..."
# ./faas_runner.py -f functions/java_greyscale.json -e $EXPERIMENT -o "$OUTPUT_DIR/java_greyscale"

# Node.js Experiments (uncomment if Node.js functions are deployed)
# echo ""
# echo "===== NODE.JS EXPERIMENTS ====="
# echo "Running Node.js Rotate..."
# ./faas_runner.py -f functions/nodejs_rotate.json -e $EXPERIMENT -o "$OUTPUT_DIR/nodejs_rotate"

echo ""
echo "=========================================="
echo "  ALL EXPERIMENTS COMPLETE!"
echo "=========================================="
echo ""
echo "Results saved to: $OUTPUT_DIR"
echo ""
echo "To view results:"
echo "  cd $OUTPUT_DIR"
echo "  ls -la"
echo ""
```

Make it executable and run:
```bash
cd test
chmod +x run_all_experiments.sh
./run_all_experiments.sh
```

## Step 5: Understanding the Results

After running experiments, you'll get CSV files with comprehensive metrics:

### Output Files Structure
```
results_20241209_143022/
├── python_rotate/
│   ├── language_comparison_zAll.csv          # Main results
│   ├── language_comparison_newcontainer.csv  # Cold start analysis
│   ├── language_comparison_cpuType.csv       # CPU type breakdown
│   └── language_comparison_vmID.csv          # VM tenancy analysis
├── python_resize/
│   └── ...
└── python_greyscale/
    └── ...
```

### Key Metrics in CSV Files

| Metric | Description |
|--------|-------------|
| **runtime** | Function execution time (ms) |
| **latency** | Round-trip time minus runtime (network overhead) |
| **roundTripTime** | Total time from request to response |
| **newcontainer** | 1 = cold start, 0 = warm start |
| **cpuType** | CPU model (for performance context) |
| **containerID** | Unique container identifier |
| **vmID** | Virtual machine identifier |
| **vmuptime** | VM uptime (to analyze container reuse) |

## Step 6: Analyzing Results for Report

### Calculate Key Statistics

For each language/function combination, calculate:

1. **Average Runtime**
   ```bash
   # Using Python/pandas
   import pandas as pd
   df = pd.read_csv('language_comparison_zAll.csv')
   print(f"Mean runtime: {df['runtime'].mean():.2f} ms")
   print(f"Std dev: {df['runtime'].std():.2f} ms")
   print(f"Median: {df['runtime'].median():.2f} ms")
   ```

2. **Cold Start Frequency**
   ```bash
   cold_starts = df['newcontainer'].sum()
   total_runs = len(df)
   cold_start_pct = (cold_starts / total_runs) * 100
   print(f"Cold start rate: {cold_start_pct:.1f}%")
   ```

3. **Warm Start Performance**
   ```bash
   warm_runs = df[df['newcontainer'] == 0]
   print(f"Warm start avg: {warm_runs['runtime'].mean():.2f} ms")
   ```

### Comparison Table Example

| Function | Language | Avg Runtime (ms) | Std Dev | Cold Starts | Warm Avg (ms) |
|----------|----------|------------------|---------|-------------|---------------|
| Rotate | Python | 245.3 | 12.4 | 8% | 238.1 |
| Rotate | Java | 312.7 | 18.9 | 12% | 298.4 |
| Rotate | Node.js | 198.5 | 10.2 | 10% | 192.3 |
| Resize | Python | 387.2 | 22.1 | 8% | 380.5 |
| Resize | Java | 425.8 | 28.3 | 12% | 410.2 |
| Resize | Node.js | 356.9 | 19.4 | 10% | 349.7 |
| Greyscale | Python | 312.4 | 15.7 | 8% | 305.8 |
| Greyscale | Java | 348.9 | 21.2 | 12% | 335.1 |
| Greyscale | Node.js | 289.3 | 14.1 | 10% | 282.6 |

## Step 7: Generating Visualizations

### Using Python/Matplotlib

```python
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# Load all results
python_rotate = pd.read_csv('results/.../python_rotate/language_comparison_zAll.csv')
java_rotate = pd.read_csv('results/.../java_rotate/language_comparison_zAll.csv')
nodejs_rotate = pd.read_csv('results/.../nodejs_rotate/language_comparison_zAll.csv')

# Create comparison plot
fig, ax = plt.subplots(figsize=(10, 6))

languages = ['Python', 'Java', 'Node.js']
runtimes = [
    python_rotate['runtime'].mean(),
    java_rotate['runtime'].mean(),
    nodejs_rotate['runtime'].mean()
]
errors = [
    python_rotate['runtime'].std(),
    java_rotate['runtime'].std(),
    nodejs_rotate['runtime'].std()
]

ax.bar(languages, runtimes, yerr=errors, capsize=10)
ax.set_ylabel('Average Runtime (ms)')
ax.set_title('Rotate Function Performance by Language')
ax.grid(axis='y', alpha=0.3)

plt.savefig('rotate_comparison.png', dpi=300, bbox_inches='tight')
plt.show()
```

## Step 8: For Your Report/Presentation

### Methodology Section

**"We conducted systematic performance testing using the SAAF (Serverless Application Analytics Framework) to compare Java, Python, and Node.js implementations. For each language, we deployed three image processing functions (Rotate 180°, Resize 150%, Grayscale) to AWS Lambda with identical configurations (512 MB memory, 900s timeout). We executed 50 iterations of each function with controlled intervals (2s sleep time) to ensure fair comparison across cold and warm starts. All implementations used line-by-line equivalent logic to isolate language-specific performance characteristics from algorithmic differences."**

### Results Presentation

1. **Runtime Comparison**: Bar chart showing average runtime by language/function
2. **Cold Start Analysis**: Stacked bar showing cold vs warm start percentages
3. **Statistical Significance**: T-tests between language pairs
4. **CPU Characteristics**: Breakdown by CPU type to control for hardware variation

## Troubleshooting

### Error: "can't parse the response"
- ✅ Should be fixed with json.loads change
- Check: Lambda function is returning Inspector metrics (dict/JSON)

### Error: "No response"
- Check: Function name matches deployed function
- Check: AWS credentials are valid
- Check: Function timeout isn't being exceeded

### Error: Missing metrics
- Check: Inspector.finish() is being called
- Check: Return value includes Inspector metrics

### Empty CSV files
- Check: Runs completed successfully (look for "successful" messages)
- Check: warmupBuffer isn't filtering out all runs

## Summary

This comprehensive testing approach gives you:
✅ Automated, repeatable experiments
✅ Statistical significance (50+ iterations)
✅ Detailed performance metrics (runtime, latency, cold starts)
✅ Fair comparison (identical logic, controlled conditions)
✅ Publication-ready data for your report

Your project now has rigorous methodology instead of manual testing!
