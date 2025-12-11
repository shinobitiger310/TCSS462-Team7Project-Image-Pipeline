#!/bin/bash

#
# Python Pipeline Test
#
# Tests the complete Python pipeline: rotate → resize → greyscale
# Uses direct invocation mode with payload passing between stages
#

echo "======================================================================"
echo "  Python Pipeline Test"
echo "======================================================================"
echo ""
echo "Pipeline: python_rotate → python_resize → python_greyscale"
echo "Runs: 10"
echo "Threads: 5"
echo "Mode: Direct invocation with payload passing"
echo ""
echo "----------------------------------------------------------------------"

# Change to test directory
cd "$(dirname "$0")"

# Run Python pipeline test
python3 faas_runner.py \
  -f ./functions/python_rotate.json \
     ./functions/python_resize.json \
     ./functions/python_greyscale.json \
  -e ./experiments/pipeline_python.json \
  -o ./history/pipeline_python

echo ""
echo "======================================================================"
echo "  Python Pipeline Test Complete!"
echo "======================================================================"
echo ""
echo "Results saved to: ./history/pipeline_python"
echo ""
