#!/bin/bash

echo "===== Installing Python 3.12 from Source ====="
echo ""

# Step 1: Install build dependencies
echo "Step 1/4: Installing build dependencies..."
sudo apt update
sudo apt install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev \
    libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev \
    wget libbz2-dev liblzma-dev

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install build dependencies"
    exit 1
fi

echo ""
echo "Step 2/4: Downloading Python 3.12.0..."
cd /tmp
wget https://www.python.org/ftp/python/3.12.0/Python-3.12.0.tgz

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to download Python 3.12.0"
    exit 1
fi

echo ""
echo "Step 3/4: Extracting and configuring Python 3.12.0..."
tar -xf Python-3.12.0.tgz
cd Python-3.12.0

# Configure with optimizations
./configure --enable-optimizations

if [ $? -ne 0 ]; then
    echo "ERROR: Configure failed"
    exit 1
fi

echo ""
echo "Step 4/4: Building and installing Python 3.12.0..."
echo "(This may take 10-15 minutes...)"
make -j $(nproc)

if [ $? -ne 0 ]; then
    echo "ERROR: Build failed"
    exit 1
fi

sudo make altinstall

if [ $? -ne 0 ]; then
    echo "ERROR: Installation failed"
    exit 1
fi

echo ""
echo "===== Installation Complete ====="
echo ""
echo "Verifying installation..."
python3.12 --version
python3.12 -m pip --version

echo ""
echo "Python 3.12 installed successfully!"
echo ""
echo "Next steps:"
echo "1. Clean old package folders: rm -rf python_lambda_*/deploy/package"
echo "2. Run deployment: ./deploy_all_python.sh"
echo ""
