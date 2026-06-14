#!/usr/bin/env bash
# ==============================================================================
#  13 — Amazon EventBridge Operations
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

print_banner "AMAZON EVENTBRIDGE — Event Bus" "📅"
check_localstack

BUS_NAME="demo-app-bus"

# ── Create Custom Event Bus ──
section_start "1. Create Event Bus"
log_step "Creating custom event bus: ${BUS_NAME}"
BUS_ARN=$($AWS_CMD events create-event-bus \
    --name "${BUS_NAME}" \
    --query 'EventBusArn' --output text 2>/dev/null || echo "exists")
if [ "$BUS_ARN" = "exists" ]; then
    BUS_ARN=$($AWS_CMD events describe-event-bus --name "${BUS_NAME}" --query 'Arn' --output text 2>/dev/null)
fi
log_success "Event Bus ARN: ${BUS_ARN}"

log_step "Listing event buses"
$AWS_CMD events list-event-buses --output json | python3 -c "
import json, sys
for bus in json.load(sys.stdin).get('EventBuses', []):
    print(f'   • {bus[\"Name\"]}')
" 2>/dev/null
section_end

# ── Create SQS Target ──
section_start "2. Create Target Queue"
TARGET_URL=$($AWS_CMD sqs create-queue --queue-name "eventbridge-target" --query 'QueueUrl' --output text 2>/dev/null)
TARGET_ARN=$($AWS_CMD sqs get-queue-attributes --queue-url "${TARGET_URL}" --attribute-names QueueArn --query 'Attributes.QueueArn' --output text 2>/dev/null)
log_success "Target Queue: ${TARGET_ARN}"
section_end

# ── Create Rules ──
section_start "3. Create Event Rules"

log_step "Rule: capture order events"
$AWS_CMD events put-rule \
    --name "order-events-rule" \
    --event-bus-name "${BUS_NAME}" \
    --event-pattern '{
        "source": ["com.app.orders"],
        "detail-type": ["OrderCreated", "OrderShipped", "OrderCancelled"]
    }' \
    --state ENABLED \
    --description "Capture all order lifecycle events" 2>/dev/null
log_success "Rule created: order-events-rule"

log_step "Rule: capture high-value orders only"
$AWS_CMD events put-rule \
    --name "high-value-orders-rule" \
    --event-bus-name "${BUS_NAME}" \
    --event-pattern '{
        "source": ["com.app.orders"],
        "detail-type": ["OrderCreated"],
        "detail": {
            "total": [{"numeric": [">=", 100]}]
        }
    }' \
    --state ENABLED \
    --description "Capture orders >= $100" 2>/dev/null
log_success "Rule created: high-value-orders-rule"

log_step "Rule: scheduled (cron)"
$AWS_CMD events put-rule \
    --name "daily-health-check" \
    --schedule-expression "rate(1 day)" \
    --state ENABLED \
    --description "Daily health check trigger" 2>/dev/null
log_success "Rule created: daily-health-check (scheduled)"
section_end

# ── Attach Targets ──
section_start "4. Attach Targets to Rules"
log_step "Attaching SQS target to order-events-rule"
$AWS_CMD events put-targets \
    --rule "order-events-rule" \
    --event-bus-name "${BUS_NAME}" \
    --targets "Id=sqs-target,Arn=${TARGET_ARN}" 2>/dev/null
log_success "Target attached"

log_step "Attaching SQS target to high-value-orders-rule"
$AWS_CMD events put-targets \
    --rule "high-value-orders-rule" \
    --event-bus-name "${BUS_NAME}" \
    --targets "Id=sqs-high-value,Arn=${TARGET_ARN}" 2>/dev/null
log_success "Target attached"
section_end

# ── List Rules ──
section_start "5. List Rules"
$AWS_CMD events list-rules \
    --event-bus-name "${BUS_NAME}" \
    --output json 2>/dev/null | python3 -c "
import json, sys
rules = json.load(sys.stdin).get('Rules', [])
for r in rules:
    print(f'   • {r[\"Name\"]:<30} {r[\"State\"]:<10} {r.get(\"Description\",\"\")[:40]}')
" 2>/dev/null

$AWS_CMD events list-rules --output json 2>/dev/null | python3 -c "
import json, sys
rules = json.load(sys.stdin).get('Rules', [])
scheduled = [r for r in rules if r.get('ScheduleExpression')]
if scheduled:
    print(f'   Scheduled rules (default bus):')
    for r in scheduled:
        print(f'     • {r[\"Name\"]}: {r[\"ScheduleExpression\"]}')
" 2>/dev/null
section_end

# ── Put Events ──
section_start "6. Publish Events"

log_step "Publishing OrderCreated event (total: \$249.99)"
$AWS_CMD events put-events --entries '[
    {
        "EventBusName": "'${BUS_NAME}'",
        "Source": "com.app.orders",
        "DetailType": "OrderCreated",
        "Detail": "{\"orderId\":\"ORD-5001\",\"customerId\":\"CUST-A\",\"total\":249.99,\"items\":[{\"sku\":\"WIDGET-PRO\",\"qty\":5}]}"
    }
]' --output json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'   Entries sent: {len(d.get(\"Entries\", []))}')
print(f'   Failed: {d.get(\"FailedEntryCount\", 0)}')
" 2>/dev/null
log_success "High-value order event published"

log_step "Publishing OrderShipped event"
$AWS_CMD events put-events --entries '[
    {
        "EventBusName": "'${BUS_NAME}'",
        "Source": "com.app.orders",
        "DetailType": "OrderShipped",
        "Detail": "{\"orderId\":\"ORD-5001\",\"trackingNumber\":\"1Z999AA10123456784\",\"carrier\":\"UPS\"}"
    }
]' 2>/dev/null
log_success "Shipped event published"

log_step "Publishing small order (total: \$19.99 — should NOT trigger high-value rule)"
$AWS_CMD events put-events --entries '[
    {
        "EventBusName": "'${BUS_NAME}'",
        "Source": "com.app.orders",
        "DetailType": "OrderCreated",
        "Detail": "{\"orderId\":\"ORD-5002\",\"customerId\":\"CUST-B\",\"total\":19.99}"
    }
]' 2>/dev/null
log_success "Small order event published"

sleep 1

# ── Verify target received events ──
log_step "Verifying target queue received events"
MSG_COUNT=$($AWS_CMD sqs get-queue-attributes \
    --queue-url "${TARGET_URL}" \
    --attribute-names ApproximateNumberOfMessages \
    --query 'Attributes.ApproximateNumberOfMessages' --output text 2>/dev/null)
log_detail "Messages on target queue: ${MSG_COUNT}"
section_end

# ── Describe Rule ──
section_start "7. Rule Details"
$AWS_CMD events describe-rule \
    --name "order-events-rule" \
    --event-bus-name "${BUS_NAME}" \
    --output json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'   Name:         {d.get(\"Name\",\"N/A\")}')
print(f'   State:        {d.get(\"State\",\"N/A\")}')
print(f'   ARN:          {d.get(\"Arn\",\"N/A\")}')
print(f'   Description:  {d.get(\"Description\",\"N/A\")}')
pattern = json.loads(d.get('EventPattern', '{}'))
print(f'   Pattern:')
print(f'     Source:      {pattern.get(\"source\", [])}')
print(f'     DetailType:  {pattern.get(\"detail-type\", [])}')
" 2>/dev/null
section_end

summary_box "EventBridge Operations Complete" \
    "Event Bus: custom + default" \
    "Rules: pattern-based, numeric filter, scheduled" \
    "Events: published with detail filtering" \
    "Targets: SQS queue integration"
