# Function Definition Files - Complete Summary

## All Function Files Created

I've created **9 function definition files** for testing all three languages:

### Python Functions (3 files)
```
test/functions/python_rotate.json      → python_lambda_rotate
test/functions/python_resize.json      → python_lambda_resize
test/functions/python_greyscale.json   → python_lambda_greyscale
```

### Java Functions (3 files)
```
test/functions/java_rotate.json        → java_lambda_rotate
test/functions/java_resize.json        → java_lambda_resize
test/functions/java_grayscale.json     → java_lambda_grayscale
```

### Node.js Functions (3 files)
```
test/functions/nodejs_rotate.json      → nodejs_lambda_rotate
test/functions/nodejs_resize.json      → nodejs_lambda_resize
test/functions/nodejs_greyscale.json   → nodejs_lambda_greyscale
```

## Expected Lambda Function Names

When deployed to AWS, these are the function names that should exist:

| Language | Rotate | Resize | Grayscale |
|----------|--------|--------|-----------|
| **Python** | python_lambda_rotate | python_lambda_resize | python_lambda_greyscale |
| **Java** | java_lambda_rotate | java_lambda_resize | java_lambda_grayscale |
| **Node.js** | nodejs_lambda_rotate | nodejs_lambda_resize | nodejs_lambda_greyscale |

## Testing Setup

### Step 1: Verify Functions Are Deployed

```bash
cd test
./check_deployed_functions.sh
```

This will show which functions are deployed and which are missing.

### Step 2: Quick Test (One Language)

```bash
# Test Python only (3 runs)
./quick_test.sh

# Or test specific function
./faas_runner.py -f functions/python_rotate.json -e experiments/quick_test.json -o ./test_results
```

### Step 3: Run All Languages

```bash
# Run all 9 functions (Python + Java + Node.js)
./run_all_experiments.sh
```

This will run 50 iterations each for a total of **450 function invocations** (9 functions × 50 runs).

## File Structure

```
test/
├── functions/
│   ├── python_rotate.json       ✓ Created
│   ├── python_resize.json       ✓ Created
│   ├── python_greyscale.json    ✓ Created
│   ├── java_rotate.json         ✓ Created
│   ├── java_resize.json         ✓ Created
│   ├── java_grayscale.json      ✓ Created
│   ├── nodejs_rotate.json       ✓ Created
│   ├── nodejs_resize.json       ✓ Created
│   └── nodejs_greyscale.json    ✓ Created
│
├── experiments/
│   ├── quick_test.json          ✓ Created (3 runs for testing)
│   └── language_comparison.json ✓ Created (50 runs for analysis)
│
└── scripts/
    ├── quick_test.sh                ✓ Test one function
    ├── run_all_experiments.sh       ✓ Run all 9 functions
    └── check_deployed_functions.sh  ✓ Verify deployments
```

## Results Directory Structure

After running `./run_all_experiments.sh`, you'll get:

```
results_TIMESTAMP/
├── python_rotate/
│   ├── language_comparison_zAll.csv
│   ├── language_comparison_newcontainer.csv
│   └── ...
├── python_resize/
├── python_greyscale/
├── java_rotate/
├── java_resize/
├── java_grayscale/
├── nodejs_rotate/
├── nodejs_resize/
└── nodejs_greyscale/
```

Each directory contains CSV files with performance metrics for that specific function.

## Analysis Example

### Compare Rotate Function Across Languages

```python
import pandas as pd

# Load results
python_rotate = pd.read_csv('results/.../python_rotate/language_comparison_zAll.csv')
java_rotate = pd.read_csv('results/.../java_rotate/language_comparison_zAll.csv')
nodejs_rotate = pd.read_csv('results/.../nodejs_rotate/language_comparison_zAll.csv')

# Calculate averages
print(f"Python Rotate: {python_rotate['runtime'].mean():.2f} ms")
print(f"Java Rotate: {java_rotate['runtime'].mean():.2f} ms")
print(f"Node.js Rotate: {nodejs_rotate['runtime'].mean():.2f} ms")
```

### Compare All Functions Across All Languages

```python
functions = ['rotate', 'resize', 'greyscale']
languages = ['python', 'java', 'nodejs']

for func in functions:
    print(f"\n{func.upper()} Function:")
    for lang in languages:
        path = f'results/.../{lang}_{func}/language_comparison_zAll.csv'
        df = pd.read_csv(path)
        avg = df['runtime'].mean()
        std = df['runtime'].std()
        print(f"  {lang:8s}: {avg:6.2f} ms (±{std:.2f})")
```

## Troubleshooting

### Function Not Found Error

If you get "ResourceNotFoundException" or function not found:

1. Check deployment:
   ```bash
   aws lambda list-functions | grep lambda_rotate
   ```

2. Verify function name matches:
   - Check `test/functions/LANGUAGE_FUNCTION.json`
   - Compare with deployed function name in AWS

3. Redeploy if needed:
   - Python: `cd python_deployment && ./deploy_all_python.sh`
   - Java: Deploy each handler separately
   - Node.js: `cd nodejs_template/deploy && ./publish.sh`

### Response Parsing Error

If you still get "can't parse response":
- Verify the fix was applied to `test/tools/experiment_caller.py`
- Check that line 118 uses `json.loads(response)` not `ast.literal_eval(response)`

### No Results in CSV

If CSV files are empty:
- Check that functions completed successfully
- Look for "Run X.Y successful" messages in output
- Verify `warmupBuffer` isn't filtering all results (set to 5 in config)

## Summary

✅ **9 function files** created for all three languages
✅ **Complete experiment setup** ready to run
✅ **Verification script** to check deployments
✅ **Automated testing** for systematic comparison

You can now run comprehensive performance experiments across Java, Python, and Node.js!
