import json
def lambda_handler(event, context):
    for record in event.get('Records', []):
        print(f"Processed SQS/SNS record: {record['messageId']}")
    return {"statusCode": 200}
