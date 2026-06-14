"""
AWS Lambda Handler — API Gateway Processor
============================================
Lambda function integrated with API Gateway (Lambda Proxy Integration).
Demonstrates:
  • HTTP method routing (GET, POST, PUT, DELETE)
  • Path parameter extraction
  • Query string handling
  • Request body parsing
  • CORS headers
  • Input validation
  • Structured API responses
"""

import json
import uuid
import time
from datetime import datetime, timezone

# ── In-memory store (simulates DynamoDB) ──
DATA_STORE = {}


def handler(event, context):
    """
    API Gateway Lambda Proxy handler.
    Routes requests based on HTTP method and path.

    Supported routes:
      GET    /items          → List all items
      GET    /items/{id}     → Get single item
      POST   /items          → Create item
      PUT    /items/{id}     → Update item
      DELETE /items/{id}     → Delete item
      GET    /health         → Health check
    """
    try:
        http_method = event.get("httpMethod", "GET")
        path = event.get("path", "/")
        path_params = event.get("pathParameters") or {}
        query_params = event.get("queryStringParameters") or {}
        body = _parse_body(event.get("body"))

        # ── Route request ──
        if path == "/health" or path == "/api/health":
            return _response(200, {
                "status": "healthy",
                "timestamp": _now(),
                "version": "1.0.0",
            })

        if "/items" in path:
            item_id = path_params.get("id") or _extract_path_id(path)

            if http_method == "GET" and not item_id:
                return _list_items(query_params)
            elif http_method == "GET" and item_id:
                return _get_item(item_id)
            elif http_method == "POST":
                return _create_item(body)
            elif http_method == "PUT" and item_id:
                return _update_item(item_id, body)
            elif http_method == "DELETE" and item_id:
                return _delete_item(item_id)

        return _response(404, {"error": "Route not found", "path": path, "method": http_method})

    except Exception as e:
        return _response(500, {"error": str(e), "type": type(e).__name__})


# ==============================================================================
#  CRUD Operations
# ==============================================================================

def _list_items(query_params):
    """List all items with optional pagination."""
    limit = int(query_params.get("limit", 50))
    offset = int(query_params.get("offset", 0))

    items = list(DATA_STORE.values())
    paginated = items[offset:offset + limit]

    return _response(200, {
        "items": paginated,
        "total": len(items),
        "limit": limit,
        "offset": offset,
    })


def _get_item(item_id):
    """Get a single item by ID."""
    item = DATA_STORE.get(item_id)
    if not item:
        return _response(404, {"error": f"Item '{item_id}' not found"})
    return _response(200, {"item": item})


def _create_item(body):
    """Create a new item."""
    if not body or "name" not in body:
        return _response(400, {"error": "Request body must include 'name'"})

    item_id = str(uuid.uuid4())[:8]
    item = {
        "id": item_id,
        "name": body["name"],
        "description": body.get("description", ""),
        "price": body.get("price", 0),
        "created_at": _now(),
        "updated_at": _now(),
    }
    DATA_STORE[item_id] = item

    return _response(201, {"item": item, "message": "Item created successfully"})


def _update_item(item_id, body):
    """Update an existing item."""
    if item_id not in DATA_STORE:
        return _response(404, {"error": f"Item '{item_id}' not found"})

    item = DATA_STORE[item_id]
    for key in ["name", "description", "price"]:
        if key in (body or {}):
            item[key] = body[key]
    item["updated_at"] = _now()
    DATA_STORE[item_id] = item

    return _response(200, {"item": item, "message": "Item updated successfully"})


def _delete_item(item_id):
    """Delete an item."""
    if item_id not in DATA_STORE:
        return _response(404, {"error": f"Item '{item_id}' not found"})

    deleted = DATA_STORE.pop(item_id)
    return _response(200, {"deleted": deleted, "message": "Item deleted successfully"})


# ==============================================================================
#  Helpers
# ==============================================================================

def _parse_body(body):
    """Parse request body (JSON string → dict)."""
    if not body:
        return {}
    if isinstance(body, str):
        try:
            return json.loads(body)
        except json.JSONDecodeError:
            return {}
    return body


def _extract_path_id(path):
    """Extract item ID from path like /items/abc123."""
    parts = [p for p in path.split("/") if p]
    if len(parts) >= 2 and parts[0] == "items":
        return parts[1]
    return None


def _now():
    """Current UTC timestamp in ISO format."""
    return datetime.now(timezone.utc).isoformat()


def _response(status_code, body):
    """Build API Gateway proxy response with CORS headers."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "X-Request-Time": _now(),
        },
        "body": json.dumps(body, default=str),
    }
