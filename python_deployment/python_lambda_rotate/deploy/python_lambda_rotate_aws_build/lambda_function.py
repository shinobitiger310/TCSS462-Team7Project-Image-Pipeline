import handler
import json

#
# AWS Lambda Functions Default Function
#
# This handler is used as a bridge to call the platform neutral
# version in handler.py. This script is put into the src directory
# when using publish.sh.
#
# @param event The AWS Lambda event
# @param context The AWS Lambda context
#
def lambda_handler(event, context):
    return handler.lambda_handler(event, context)
