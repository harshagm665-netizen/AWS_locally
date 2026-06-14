#!/usr/bin/env bash
# ==============================================================================
#  11 — AWS Step Functions Operations
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

print_banner "AWS STEP FUNCTIONS — State Machines" "🔀"
check_localstack

ROLE_ARN="arn:aws:iam::000000000000:role/stepfunctions-role"

# ── Create IAM Role ──
section_start "1. Create Execution Role"
$AWS_CMD iam create-role \
    --role-name stepfunctions-role \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"states.amazonaws.com"},"Action":"sts:AssumeRole"}]}' 2>/dev/null || true
ROLE_ARN=$($AWS_CMD iam get-role --role-name stepfunctions-role --query 'Role.Arn' --output text 2>/dev/null || echo "$ROLE_ARN")
log_success "Role: ${ROLE_ARN}"
section_end

# ── Create State Machine: Order Processing Pipeline ──
section_start "2. Create State Machine"

ORDER_DEFINITION='{
  "Comment": "Order Processing Pipeline — validates, charges, and fulfills orders",
  "StartAt": "ValidateOrder",
  "States": {
    "ValidateOrder": {
      "Type": "Pass",
      "Result": {"status": "validated", "orderId": "ORD-001"},
      "ResultPath": "$.validation",
      "Next": "CheckInventory"
    },
    "CheckInventory": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.validation.status",
          "StringEquals": "validated",
          "Next": "ProcessPayment"
        }
      ],
      "Default": "OrderFailed"
    },
    "ProcessPayment": {
      "Type": "Pass",
      "Result": {"paymentStatus": "charged", "transactionId": "TXN-12345"},
      "ResultPath": "$.payment",
      "Next": "FulfillOrder"
    },
    "FulfillOrder": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "UpdateInventory",
          "States": {
            "UpdateInventory": {
              "Type": "Pass",
              "Result": {"inventory": "updated"},
              "End": true
            }
          }
        },
        {
          "StartAt": "SendConfirmation",
          "States": {
            "SendConfirmation": {
              "Type": "Pass",
              "Result": {"notification": "sent"},
              "End": true
            }
          }
        }
      ],
      "Next": "OrderComplete"
    },
    "OrderComplete": {
      "Type": "Succeed"
    },
    "OrderFailed": {
      "Type": "Fail",
      "Error": "OrderValidationFailed",
      "Cause": "Order did not pass validation checks"
    }
  }
}'

log_step "Creating state machine: order-processing-pipeline"
SM_ARN=$($AWS_CMD stepfunctions create-state-machine \
    --name "order-processing-pipeline" \
    --definition "$ORDER_DEFINITION" \
    --role-arn "${ROLE_ARN}" \
    --type STANDARD \
    --query 'stateMachineArn' --output text 2>/dev/null || echo "already-exists")

if [ "$SM_ARN" = "already-exists" ]; then
    SM_ARN=$($AWS_CMD stepfunctions list-state-machines --query "stateMachines[?name=='order-processing-pipeline'].stateMachineArn" --output text 2>/dev/null)
fi
log_success "State Machine ARN: ${SM_ARN}"
section_end

# ── List State Machines ──
section_start "3. List State Machines"
$AWS_CMD stepfunctions list-state-machines --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for sm in data.get('stateMachines', []):
    print(f'   • {sm[\"name\"]:<35} {sm[\"type\"]:<10} {str(sm.get(\"creationDate\",\"\"))[:19]}')
" 2>/dev/null
section_end

# ── Execute State Machine ──
section_start "4. Start Execution"
log_step "Starting execution with order payload"
EXEC_ARN=$($AWS_CMD stepfunctions start-execution \
    --state-machine-arn "${SM_ARN}" \
    --name "exec-$(date +%s)" \
    --input '{"orderId":"ORD-2025-001","customerId":"CUST-A","items":[{"sku":"WIDGET-01","qty":2,"price":29.99}],"total":59.98}' \
    --query 'executionArn' --output text 2>/dev/null)
log_success "Execution ARN: ${EXEC_ARN}"

sleep 2

# ── Describe Execution ──
log_step "Checking execution status"
$AWS_CMD stepfunctions describe-execution \
    --execution-arn "${EXEC_ARN}" \
    --output json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'   Status:    {d.get(\"status\", \"N/A\")}')
print(f'   Started:   {str(d.get(\"startDate\", \"N/A\"))[:19]}')
print(f'   Stopped:   {str(d.get(\"stopDate\", \"N/A\"))[:19]}')
output = d.get('output')
if output:
    print(f'   Output:    {output[:100]}...')
" 2>/dev/null
section_end

# ── Execution History ──
section_start "5. Execution History"
$AWS_CMD stepfunctions get-execution-history \
    --execution-arn "${EXEC_ARN}" \
    --output json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
events = data.get('events', [])[:15]
for e in events:
    ts = str(e.get('timestamp', ''))[:19]
    etype = e.get('type', '?')
    print(f'   {e[\"id\"]:>3}  {ts}  {etype}')
print(f'\n   Total events: {len(data.get(\"events\", []))}')
" 2>/dev/null
section_end

summary_box "Step Functions Operations Complete" \
    "State Machine: order-processing-pipeline" \
    "States: Pass, Choice, Parallel, Succeed, Fail" \
    "Execution: started, monitored, history viewed"
