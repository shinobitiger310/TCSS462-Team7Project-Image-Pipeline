#!/bin/bash

# s3_cleanup.sh - Clean all test files from S3 buckets

echo "=========================================="
echo "S3 BUCKET CLEANUP"
echo "=========================================="
echo ""

BUCKETS=(
    "tcss462-term-project-group-7-python"
    "tcss462-term-project-group-7-jav"
    "tcss462-term-project-group-7-js"
)

PREFIXES=("input/" "stage1/" "stage2/" "output/")

echo "This will delete ALL files from test buckets."
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Starting cleanup..."

for bucket in "${BUCKETS[@]}"; do
    echo ""
    echo "Cleaning bucket: $bucket"
    echo "---"
    
    for prefix in "${PREFIXES[@]}"; do
        echo "  Removing $prefix..."
        
        # Count files before deletion
        count=$(aws s3 ls "s3://$bucket/$prefix" --region us-east-2 2>/dev/null | wc -l)
        
        if [ $count -gt 0 ]; then
            aws s3 rm "s3://$bucket/$prefix" --recursive --region us-east-2 --quiet
            echo "    ✓ Deleted $count files from $prefix"
        else
            echo "    - No files in $prefix"
        fi
    done
done

echo ""
echo "=========================================="
echo "S3 CLEANUP COMPLETE"
echo "=========================================="
echo ""

# Verify cleanup
echo "Verification - Files remaining per bucket:"
echo ""
for bucket in "${BUCKETS[@]}"; do
    total=0
    echo "$bucket:"
    for prefix in "${PREFIXES[@]}"; do
        count=$(aws s3 ls "s3://$bucket/$prefix" --region us-east-2 2>/dev/null | wc -l)
        total=$((total + count))
        echo "  $prefix: $count files"
    done
    echo "  Total: $total files"
    echo ""
done