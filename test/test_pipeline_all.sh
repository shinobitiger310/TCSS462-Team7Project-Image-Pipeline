#!/bin/bash

#
# All Languages Pipeline Comparison Test
#
# Tests all three language pipelines and compares their performance:
# - Python:  rotate → resize → greyscale
# - Java:    rotate → resize → grayscale
# - Node.js: rotate → resize → greyscale
#
# Uses direct invocation mode with payload passing between stages
#

echo "======================================================================"
echo "  All Languages Pipeline Comparison Test"
echo "======================================================================"
echo ""
echo "Testing 3 complete pipelines:"
echo "  1. Python:  python_rotate → python_resize → python_greyscale"
echo "  2. Java:    java_rotate → java_resize → java_grayscale"
echo "  3. Node.js: nodejs_rotate → nodejs_resize → nodejs_greyscale"
echo ""
echo "Runs: 50 per pipeline"
echo "Threads: 10"
echo "Mode: Direct invocation with payload passing"
echo ""
echo "This will take approximately 15-20 minutes..."
echo ""
echo "----------------------------------------------------------------------"

# Change to test directory
cd "$(dirname "$0")"

# Run all pipelines comparison test
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

echo ""
echo "======================================================================"
echo "  All Languages Pipeline Comparison Complete!"
echo "======================================================================"
echo ""
echo "Results saved to: ./history/pipeline_comparison"
echo ""
echo "To generate a comparison report:"
echo "  python3 generate_comparison_report.py ./history/pipeline_comparison"
echo ""
