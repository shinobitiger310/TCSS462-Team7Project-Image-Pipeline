#!/bin/bash

# Some issues with packaging dependencies, just use the zip files
cd "$(dirname "$0")"

echo "===== Creating zip files ====="

# Rotate
echo "Zipping rotate function..."
cd ../src/nodejs_rotate
zip -r ../../deploy/nodejs_rotate index.js Inspector.js node_modules/

# Resize
echo "Zipping resize function..."
cd ../nodejs_rotate
zip -r ../../deploy/nodejs_resize index.js Inspector.js node_modules/

# Greyscale
echo "Zipping greyscale function..."
cd ../nodejs_greyscale
zip -r ../../deploy/nodejs_greyscale index.js Inspector.js node_modules/

echo ""
echo "===== Done! ====="
echo "Created:"
echo "  - nodejs_rotate.zip"
echo "  - nodejs_resize.zip"
echo "  - nodejs_greyscale.zip"
echo ""
echo "Upload each zip to its Lambda function in AWS Console:"
echo "  - nodejs_rotate.zip    → nodejs_rotate"
echo "  - nodejs_resize.zip      → nodejs_resize"
echo "  - nodejs_greyscale.zip → nodejs_greyscale"
