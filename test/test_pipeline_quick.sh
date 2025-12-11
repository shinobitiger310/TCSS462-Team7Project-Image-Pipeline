#!/bin/bash

#
# Quick Pipeline Test - Tests one complete pipeline to verify dual-mode functions work
#
# This script runs a quick test of the Python pipeline (rotate → resize → greyscale)
# with just 3 runs to verify everything is working before running full experiments.
#

echo "======================================================================"
echo "  Quick Pipeline Test - Python Pipeline"
echo "======================================================================"
echo ""
echo "This will test: python_rotate → python_resize → python_greyscale"
echo "Runs: 3 (quick test)"
echo "Mode: Direct invocation with payload passing (Tutorial 10)"
echo ""
echo "----------------------------------------------------------------------"

# Change to test directory
cd "$(dirname "$0")"

# Run quick pipeline test (3 runs only)
python3 faas_runner.py \
  -f ./functions/python_rotate.json \
     ./functions/python_resize.json \
     ./functions/python_greyscale.json \
  -e ./experiments/pipeline_python.json \
  -o ./history/pipeline_quick_test \
  --runs 3

echo ""
echo "======================================================================"
echo "  Quick Test Complete!"
echo "======================================================================"
echo ""
echo "Results saved to: ./history/pipeline_quick_test"
echo ""
echo "To run full pipeline tests (10 runs each):"
echo "  - Python:  ./test_pipeline_python.sh"
echo "  - Java:    ./test_pipeline_java.sh"
echo "  - Node.js: ./test_pipeline_nodejs.sh"
echo ""
echo "To compare all languages:"
echo "  - ./test_pipeline_all.sh"
echo ""
