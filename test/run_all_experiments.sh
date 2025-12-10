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

# Java Experiments
echo ""
echo "===== JAVA EXPERIMENTS ====="
echo "Running Java Rotate..."
./faas_runner.py -f functions/java_rotate.json -e $EXPERIMENT -o "$OUTPUT_DIR/java_rotate"

echo ""
echo "Running Java Resize..."
./faas_runner.py -f functions/java_resize.json -e $EXPERIMENT -o "$OUTPUT_DIR/java_resize"

echo ""
echo "Running Java Greyscale..."
./faas_runner.py -f functions/java_grayscale.json -e $EXPERIMENT -o "$OUTPUT_DIR/java_grayscale"

# Node.js Experiments
echo ""
echo "===== NODE.JS EXPERIMENTS ====="
echo "Running Node.js Rotate..."
./faas_runner.py -f functions/nodejs_rotate.json -e $EXPERIMENT -o "$OUTPUT_DIR/nodejs_rotate"

echo ""
echo "Running Node.js Resize..."
./faas_runner.py -f functions/nodejs_resize.json -e $EXPERIMENT -o "$OUTPUT_DIR/nodejs_resize"

echo ""
echo "Running Node.js Greyscale..."
./faas_runner.py -f functions/nodejs_greyscale.json -e $EXPERIMENT -o "$OUTPUT_DIR/nodejs_greyscale"

echo ""
echo "=========================================="
echo "  ALL EXPERIMENTS COMPLETE!"
echo "=========================================="
echo ""
echo "Results saved to: $OUTPUT_DIR"
echo ""

# Generate unified comparison report
echo "Generating comparison report..."
./generate_comparison_report.py "$OUTPUT_DIR"

echo ""
echo "=========================================="
echo "  SUMMARY"
echo "=========================================="
echo ""
echo "Results directory: $OUTPUT_DIR"
echo ""
echo "Files created:"
echo "  - Individual CSVs in each language_function folder"
echo "  - comparison_summary.txt (unified report)"
echo ""
echo "To view comparison:"
echo "  cat $OUTPUT_DIR/comparison_summary.txt"
echo ""
