#!/bin/bash

# run_performance_tests_v2.sh - With individual test tracking

LANGUAGES=("Python" "Java" "JavaScript")
CONCURRENCY_LEVELS=(1 5 10 50 100)
BATCH_SIZE=100

RESULTS_FILE="test_results_$(date +%Y%m%d_%H%M%S).txt"
METADATA_FILE="test_metadata_$(date +%Y%m%d_%H%M%S).json"

echo "=== Performance Testing Suite ===" | tee $RESULTS_FILE
echo "Started: $(date -u +"%Y-%m-%d %H:%M:%S")" | tee -a $RESULTS_FILE
echo "" | tee -a $RESULTS_FILE

# Initialize JSON metadata
echo "{" > $METADATA_FILE
echo '  "tests": [' >> $METADATA_FILE

FIRST_TEST=true

for lang in "${LANGUAGES[@]}"; do
    for concurrency in "${CONCURRENCY_LEVELS[@]}"; do
        echo "========================================" | tee -a $RESULTS_FILE
        echo "Testing: $lang with concurrency $concurrency" | tee -a $RESULTS_FILE
        echo "========================================" | tee -a $RESULTS_FILE
        
        # Record test start time
        TEST_START=$(date -u +"%Y-%m-%d %H:%M:%S")
        echo "Test start time (UTC): $TEST_START" | tee -a $RESULTS_FILE
        
        # Run test
        ./callRouter.sh $lang $concurrency $BATCH_SIZE | tee -a $RESULTS_FILE
        
        echo "" | tee -a $RESULTS_FILE
        echo "Waiting 2 minutes for Lambda processing..." | tee -a $RESULTS_FILE
        sleep 120
        
        # Record test end time (after processing)
        TEST_END=$(date -u +"%Y-%m-%d %H:%M:%S")
        echo "Test end time (UTC): $TEST_END" | tee -a $RESULTS_FILE
        
        # Save to metadata JSON
        if [ "$FIRST_TEST" = false ]; then
            echo "," >> $METADATA_FILE
        fi
        FIRST_TEST=false
        
        cat >> $METADATA_FILE <<EOF
    {
      "language": "$lang",
      "concurrency": $concurrency,
      "batch_size": $BATCH_SIZE,
      "start_time": "$TEST_START",
      "end_time": "$TEST_END"
    }
EOF
        
        echo "---" | tee -a $RESULTS_FILE
    done
    
    # Wait 5 minutes between languages for cold start testing
    if [ "$lang" != "JavaScript" ]; then
        echo "Waiting 5 minutes for cold start reset..." | tee -a $RESULTS_FILE
        sleep 300
    fi
done

# Close JSON
echo "" >> $METADATA_FILE
echo "  ]" >> $METADATA_FILE
echo "}" >> $METADATA_FILE

echo "" | tee -a $RESULTS_FILE
echo "✓ All tests completed!" | tee -a $RESULTS_FILE
echo "Completed: $(date -u +"%Y-%m-%d %H:%M:%S")" | tee -a $RESULTS_FILE
echo "" | tee -a $RESULTS_FILE
echo "Metadata saved to: $METADATA_FILE" | tee -a $RESULTS_FILE