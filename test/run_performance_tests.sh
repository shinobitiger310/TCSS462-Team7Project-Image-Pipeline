#!/bin/bash

# Test configurations
LANGUAGES=("Python" "Java" "JavaScript")
CONCURRENCY_LEVELS=(1 5 10 50 100)
BATCH_SIZE=100

RESULTS_FILE="test_results_$(date +%Y%m%d_%H%M%S).txt"

echo "=== Performance Testing Suite ===" | tee $RESULTS_FILE
echo "Started: $(date)" | tee -a $RESULTS_FILE
echo "" | tee -a $RESULTS_FILE

for lang in "${LANGUAGES[@]}"; do
    for concurrency in "${CONCURRENCY_LEVELS[@]}"; do
        echo "========================================" | tee -a $RESULTS_FILE
        echo "Testing: $lang with concurrency $concurrency" | tee -a $RESULTS_FILE
        echo "========================================" | tee -a $RESULTS_FILE
        
        # Run test
        ./callRouter.sh $lang $concurrency $BATCH_SIZE | tee -a $RESULTS_FILE
        
        echo "" | tee -a $RESULTS_FILE
        echo "Waiting 2 minutes for Lambda processing..." | tee -a $RESULTS_FILE
        sleep 120
        
        echo "---" | tee -a $RESULTS_FILE
    done
    
    # Wait 5 minutes between languages for cold start testing
    echo "Waiting 5 minutes for cold start reset..." | tee -a $RESULTS_FILE
    sleep 300
done

echo "" | tee -a $RESULTS_FILE
echo "✓ All tests completed!" | tee -a $RESULTS_FILE
echo "Completed: $(date)" | tee -a $RESULTS_FILE