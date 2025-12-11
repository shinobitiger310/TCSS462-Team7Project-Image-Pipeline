#!/bin/bash

#
# Java Pipeline Test
#
# Tests the complete Java pipeline: rotate → resize → grayscale
# Uses direct invocation mode with payload passing between stages
#

echo "======================================================================"
echo "  Java Pipeline Test"
echo "======================================================================"
echo ""
echo "Pipeline: java_rotate → java_resize → java_grayscale"
echo "Runs: 10"
echo "Threads: 5"
echo "Mode: Direct invocation with payload passing"
echo ""
echo "----------------------------------------------------------------------"

# Change to test directory
cd "$(dirname "$0")"

# Run Java pipeline test
python3 faas_runner.py \
  -f ./functions/java_rotate.json \
     ./functions/java_resize.json \
     ./functions/java_grayscale.json \
  -e ./experiments/pipeline_java.json \
  -o ./history/pipeline_java

echo ""
echo "======================================================================"
echo "  Java Pipeline Test Complete!"
echo "======================================================================"
echo ""
echo "Results saved to: ./history/pipeline_java"
echo ""
