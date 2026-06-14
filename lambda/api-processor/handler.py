import json
import boto3
import os

def lambda_handler(event, context):
    endpoint = os.environ.get('AWS_ENDPOINT_URL', 'http://localhost:4566')
    dynamodb = boto3.client('dynamodb', endpoint_url=endpoint)
    # Simple CRUD mock
    return {"statusCode": 200, "body": json.dumps({"status": "ok", "api": "Floci proxy"})}
