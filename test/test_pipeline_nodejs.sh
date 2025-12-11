#!/bin/bash

#
# Node.js Pipeline Test
#
# Tests the complete Node.js pipeline: rotate → resize → greyscale
# Uses direct invocation mode with payload passing between stages
#

echo "======================================================================"
echo "  Node.js Pipeline Test"
echo "======================================================================"
echo ""
echo "Pipeline: nodejs_rotate → nodejs_resize → nodejs_greyscale"
echo "Runs: 10"
echo "Threads: 5"
echo "Mode: Direct invocation with payload passing"
echo ""
echo "----------------------------------------------------------------------"

# Change to test directory
cd "$(dirname "$0")"

# Run Node.js pipeline test
python3 faas_runner.py \
  -f ./functions/nodejs_rotate.json \
     ./functions/nodejs_resize.json \
     ./functions/nodejs_greyscale.json \
  -e ./experiments/pipeline_nodejs.json \
  -o ./history/pipeline_nodejs

echo ""
echo "======================================================================"
echo "  Node.js Pipeline Test Complete!"
echo "======================================================================"
echo ""
echo "Results saved to: ./history/pipeline_nodejs"
echo ""
