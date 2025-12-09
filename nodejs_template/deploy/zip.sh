#!/bin/bash

cd "$(dirname "$0")"

echo "===== Creating zip files ====="

# Rotate
echo "Zipping rotate function..."
cp ../src/rotate.js ./index.js
cp ../src/Inspector.js ./Inspector.js
cp ../src/config.js ./config.js
zip -r rotate-function.zip index.js Inspector.js config.js node_modules

# Zoom
echo "Zipping zoom function..."
cp ../src/zoom.js ./index.js
zip -r zoom-function.zip index.js Inspector.js config.js node_modules

# Greyscale
echo "Zipping greyscale function..."
cp ../src/greyscale.js ./index.js
zip -r greyscale-function.zip index.js Inspector.js config.js node_modules

# Cleanup
rm -f index.js Inspector.js config.js

echo ""
echo "===== Done! ====="
echo "Created:"
echo "  - rotate-function.zip"
echo "  - zoom-function.zip"
echo "  - greyscale-function.zip"
echo ""
echo "Upload each zip to its Lambda function in AWS Console:"
echo "  - rotate-function.zip    → nodejs_lambda_rotate"
echo "  - zoom-function.zip      → nodejs_lambda_resize"
echo "  - greyscale-function.zip → nodejs_lambda_greyscale"