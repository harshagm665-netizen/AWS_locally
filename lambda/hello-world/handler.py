"""
AWS Lambda Handler — Hello World
=================================
Basic Lambda function demonstrating:
  • Event parsing and context usage
  • Structured JSON response
  • Environment variable access
  • Cold start vs warm start tracking
  • Proper error handling
"""

import json
import os
import time
from datetime import datetime, timezone

# ── Cold start tracking ──
COLD_START = True
INIT_TIME = datetime.now(timezone.utc).isoformat()


def handler(event, context):
    """
    Main Lambda handler.

    Args:
        event (dict): Incoming event data (can be direct invoke, scheduled, etc.)
        context (LambdaContext): Runtime information

    Returns:
        dict: Structured response with status code and body
    """
    global COLD_START

    start_time = time.time()

    try:
        # ── Build response payload ──
        response_body = {
            "message": "Hello from LocalStack Lambda! 🚀",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "function": {
                "name": getattr(context, "function_name", "hello-world"),
                "version": getattr(context, "function_version", "$LATEST"),
                "memory_mb": getattr(context, "memory_limit_in_mb", "128"),
                "region": os.environ.get("AWS_REGION", "us-east-1"),
            },
            "execution": {
                "request_id": getattr(context, "aws_request_id", "local"),
                "cold_start": COLD_START,
                "init_time": INIT_TIME,
                "duration_ms": round((time.time() - start_time) * 1000, 2),
            },
            "event_summary": {
                "keys": list(event.keys()) if isinstance(event, dict) else str(type(event)),
                "source": event.get("source", "direct-invoke"),
            },
            "environment": os.environ.get("ENVIRONMENT", "local"),
        }

        # ── Track warm starts after first invocation ──
        COLD_START = False

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "X-Request-Id": getattr(context, "aws_request_id", "local"),
                "X-Cold-Start": str(COLD_START),
            },
            "body": json.dumps(response_body, indent=2),
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "error": str(e),
                "type": type(e).__name__,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }),
        }
