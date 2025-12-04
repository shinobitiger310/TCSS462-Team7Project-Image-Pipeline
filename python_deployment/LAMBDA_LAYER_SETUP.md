# Using AWS Lambda Layers for Pillow

Instead of packaging Pillow with each function, we'll use AWS Lambda Layers which provide pre-built, Lambda-compatible libraries.

## Option 1: Use AWS Public Lambda Layer (Recommended)

AWS community maintains public Lambda Layers with Pillow. Here's how to add them:

### Step 1: Find the Pillow Layer ARN

For Python 3.12 in us-east-2, use this ARN:
```
arn:aws:lambda:us-east-2:770693421928:layer:Klayers-p312-pillow:1
```

For other regions, visit: https://github.com/keithrozario/Klayers

### Step 2: Add Layer to Lambda Functions

```bash
# Add layer to python_lambda_rotate
aws lambda update-function-configuration \
  --function-name python_lambda_rotate \
  --layers arn:aws:lambda:us-east-2:770693421928:layer:Klayers-p312-pillow:1

# Add layer to python_lambda_resize
aws lambda update-function-configuration \
  --function-name python_lambda_resize \
  --layers arn:aws:lambda:us-east-2:770693421928:layer:Klayers-p312-pillow:1

# Add layer to python_lambda_greyscale
aws lambda update-function-configuration \
  --function-name python_lambda_greyscale \
  --layers arn:aws:lambda:us-east-2:770693421928:layer:Klayers-p312-pillow:1
```

## Option 2: Quick Test with Simplified Deployment

I can create a simplified deployment that:
- Removes boto3 packaging (already in Lambda)
- Uses Lambda Layers for Pillow
- Only packages your handler code and SAAF

Would you like me to create this simplified deployment approach?
