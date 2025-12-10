#!/bin/bash

# Install Python dependencies for AWS Lambda
# Downloads pre-compiled wheels compatible with Lambda's Amazon Linux 2

cd "$(dirname "$0")"

echo "Installing Lambda-compatible dependencies..."

# Clean existing folders
rm -rf ./package ./wheels
mkdir -p ./package ./wheels

echo "Downloading Pillow for Lambda (manylinux)..."

# Download Pillow for Python 3.12 on manylinux (Lambda compatible)
python3.12 -m pip download \
    --only-binary=:all: \
    --platform manylinux2014_x86_64 \
    --python-version 312 \
    --no-deps \
    Pillow \
    --dest ./wheels/

# Check if download succeeded
if [ ! -f ./wheels/Pillow-*cp312*.whl ]; then
    echo "manylinux2014 failed, trying manylinux_2_28..."
    python3.12 -m pip download \
        --only-binary=:all: \
        --platform manylinux_2_28_x86_64 \
        --python-version 312 \
        --no-deps \
        Pillow \
        --dest ./wheels/
fi

# Check again
if [ ! -f ./wheels/Pillow-*.whl ]; then
    echo "ERROR: Could not download Lambda-compatible Pillow wheel"
    echo "Falling back to local platform (may not work in Lambda)"
    python3.12 -m pip download --no-deps Pillow --dest ./wheels/
fi

echo ""
echo "Extracting wheels..."
cd ./wheels
if ls *.whl 1> /dev/null 2>&1; then
  for wheel in *.whl; do
    echo "  Extracting $wheel..."
    unzip -q -o "$wheel" -d ../package/
  done
else
  echo "ERROR: No wheel files found!"
  exit 1
fi
cd ..

# Clean up
rm -rf ./wheels
rm -rf ./package/*.dist-info
rm -rf ./package/*.egg-info

echo ""
echo "Dependencies installed successfully!"
echo ""
echo "Package folder size:"
du -sh ./package/
echo ""
echo "Checking for PIL module:"
ls -d ./package/PIL 2>/dev/null && echo "✓ PIL found" || echo "✗ PIL not found"
echo ""
echo "Checking for _imaging.so:"
find ./package/PIL -name "*_imaging*.so" 2>/dev/null | head -3

