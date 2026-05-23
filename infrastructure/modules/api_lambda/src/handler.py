import json
import os
import boto3

sqs = boto3.client("sqs")
QUEUE_URL = os.environ["QUEUE_URL"]


def handler(event, context):
    body = event.get("body", "{}")
    sqs.send_message(QueueUrl=QUEUE_URL, MessageBody=body)
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"message": "Order received"}),
    }
