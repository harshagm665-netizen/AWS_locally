"""
AWS Lambda Handler — Event Processor
======================================
Lambda function triggered by SQS/SNS events.
Demonstrates:
  • SQS event batch processing
  • SNS notification handling
  • Dead-letter queue routing
  • Structured logging
  • Partial batch failure reporting
"""

import json
import time
from datetime import datetime, timezone


def handler(event, context):
    """
    Process events from SQS queues or SNS topics.

    Supports:
      • SQS: event['Records'] with 'eventSource' == 'aws:sqs'
      • SNS: event['Records'] with 'EventSource' == 'aws:sns'
      • Direct: raw event payload
    """
    start_time = time.time()
    results = {
        "processed": 0,
        "failed": 0,
        "skipped": 0,
        "details": [],
        "batch_item_failures": [],
    }

    records = event.get("Records", [])

    # ── Direct invocation (no Records) ──
    if not records:
        _log("INFO", "Direct invocation — processing raw event")
        result = _process_payload(event)
        results["processed"] = 1
        results["details"].append(result)
        return _build_response(results, start_time)

    # ── Process each record in the batch ──
    for record in records:
        record_id = record.get("messageId", record.get("MessageId", "unknown"))

        try:
            source = record.get("eventSource", record.get("EventSource", "unknown"))

            if source == "aws:sqs":
                payload = _extract_sqs_payload(record)
            elif source == "aws:sns":
                payload = _extract_sns_payload(record)
            else:
                _log("WARNING", f"Unknown event source: {source}")
                results["skipped"] += 1
                continue

            result = _process_payload(payload)
            results["processed"] += 1
            results["details"].append({
                "record_id": record_id,
                "source": source,
                "result": result,
            })

            _log("INFO", f"Processed record {record_id} from {source}")

        except Exception as e:
            _log("ERROR", f"Failed to process record {record_id}: {str(e)}")
            results["failed"] += 1
            # Report partial batch failure (SQS)
            results["batch_item_failures"].append({
                "itemIdentifier": record_id,
            })

    return _build_response(results, start_time)


# ==============================================================================
#  Payload Extractors
# ==============================================================================

def _extract_sqs_payload(record):
    """Extract and parse SQS message body."""
    body = record.get("body", "{}")
    try:
        return json.loads(body)
    except json.JSONDecodeError:
        return {"raw_body": body}


def _extract_sns_payload(record):
    """Extract and parse SNS message."""
    sns = record.get("Sns", {})
    message = sns.get("Message", "{}")
    try:
        parsed = json.loads(message)
    except json.JSONDecodeError:
        parsed = {"raw_message": message}

    return {
        "subject": sns.get("Subject", ""),
        "topic_arn": sns.get("TopicArn", ""),
        "message": parsed,
        "attributes": sns.get("MessageAttributes", {}),
    }


# ==============================================================================
#  Business Logic
# ==============================================================================

def _process_payload(payload):
    """
    Core processing logic for any incoming payload.
    In production, this would contain actual business logic:
      • Data transformation
      • Database writes
      • External API calls
      • ML inference
    """
    event_type = payload.get("event", payload.get("task", "unknown"))

    return {
        "event_type": event_type,
        "processed_at": datetime.now(timezone.utc).isoformat(),
        "payload_keys": list(payload.keys()) if isinstance(payload, dict) else [],
        "status": "success",
    }


# ==============================================================================
#  Helpers
# ==============================================================================

def _log(level, message):
    """Structured logging for CloudWatch."""
    print(json.dumps({
        "level": level,
        "message": message,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": "event-processor",
    }))


def _build_response(results, start_time):
    """Build final response with execution metrics."""
    duration_ms = round((time.time() - start_time) * 1000, 2)

    response = {
        "statusCode": 200,
        "summary": {
            "processed": results["processed"],
            "failed": results["failed"],
            "skipped": results["skipped"],
            "duration_ms": duration_ms,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        },
        "details": results["details"],
    }

    # Include batch item failures for SQS partial batch response
    if results["batch_item_failures"]:
        response["batchItemFailures"] = results["batch_item_failures"]

    return response
