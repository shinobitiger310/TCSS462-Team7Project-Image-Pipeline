#!/bin/bash

# Publisher for python_lambda_greyscale
# Deploys the Lambda function to AWS
# Usage: ./publish.sh

cd "$(dirname "$0")"

# Load config.json
config="./config.json"

# Get the function name from the config file
function=$(cat $config | jq '.functionName' | tr -d '"')
handlerFile=$(cat $config | jq '.handlerFile' | tr -d '"')
json=$(cat $config | jq -c '.test')

echo
echo "Deploying $function..."
echo

# Get configuration from config.json
memory=$(cat $config | jq '.memorySetting' | tr -d '"')
lambdaHandler=$(cat $config | jq '.lambdaHandler' | tr -d '"')
lambdaRole=$(cat $config | jq '.lambdaRoleARN' | tr -d '"')
lambdaSubnets=$(cat $config | jq '.lambdaSubnets' | tr -d '"')
lambdaSecurityGroups=$(cat $config | jq '.lambdaSecurityGroups' | tr -d '"')
lambdaEnvironment=$(cat $config | jq '.lambdaEnvironment' | tr -d '"')
lambdaRuntime=$(cat $config | jq '.lambdaRuntime' | tr -d '"')

echo
echo "----- Deploying onto AWS Lambda -----"
echo

# Destroy and prepare build folder
rm -rf ${function}_aws_build
mkdir ${function}_aws_build

# Copy files to build folder
cp -R ../src/* ./${function}_aws_build
cp -R ../platforms/aws/* ./${function}_aws_build

# Copy dependencies from package folder if they exist
if [ -d "./package" ] && [ "$(ls -A ./package)" ]; then
    cp -r ./package/* ./${function}_aws_build/
fi

# Zip and submit to AWS Lambda
cd ./${function}_aws_build
mv $handlerFile handler.py
zip -X -r ./index.zip *

# Create or update function
aws lambda create-function --function-name $function --runtime $lambdaRuntime --role $lambdaRole --timeout 900 --handler $lambdaHandler --zip-file fileb://index.zip 2>/dev/null

if [ $? -ne 0 ]; then
    echo "Function exists, updating code..."
    aws lambda update-function-code --function-name $function --zip-file fileb://index.zip
fi

# Update configuration
if [ -n "$lambdaSubnets" ] && [ -n "$lambdaSecurityGroups" ]; then
    aws lambda update-function-configuration --function-name $function --memory-size $memory --timeout 900 --runtime $lambdaRuntime \
        --vpc-config SubnetIds=[$lambdaSubnets],SecurityGroupIds=[$lambdaSecurityGroups] --environment "$lambdaEnvironment"
else
    aws lambda update-function-configuration --function-name $function --memory-size $memory --timeout 900 --runtime $lambdaRuntime \
        --environment "$lambdaEnvironment"
fi

cd ..

echo
echo "Testing $function on AWS Lambda..."
aws lambda invoke --invocation-type RequestResponse --cli-read-timeout 900 --function-name $function --payload "$json" /dev/stdout

echo
echo
echo "Deployment complete!"
