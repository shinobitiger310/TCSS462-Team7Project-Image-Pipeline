#!/bin/bash

# Quick test to verify faas_runner works
# Runs 3 iterations only

echo "===== Quick Test - Python Rotate ====="
echo ""

./faas_runner.py -f functions/python_rotate.json -e experiments/quick_test.json -o ./quick_test_results

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ SUCCESS! faas_runner is working correctly."
    echo ""
    echo "Check results in: ./quick_test_results/"
    echo ""
    echo "Next steps:"
    echo "  1. Run full experiments: ./run_all_experiments.sh"
    echo "  2. Check CSV files in results directory"
else
    echo ""
    echo "✗ FAILED! Check error messages above."
fi
