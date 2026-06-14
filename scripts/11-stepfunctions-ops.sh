#!/usr/bin/env bash
# ══ 11 — AWS Step Functions Operations (Floci) ══
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
print_banner "AWS STEP FUNCTIONS" "🔀"
check_floci

ROLE_ARN="arn:aws:iam::000000000000:role/stepfunctions-role"
DEF='{"Comment":"A Hello World example","StartAt":"HelloWorld","States":{"HelloWorld":{"Type":"Pass","Result":"Hello World!","End":true}}}'

section_start "1. Create State Machine"
SM_ARN=$($AWS_CMD stepfunctions create-state-machine \
    --name "demo-machine" \
    --definition "${DEF}" \
    --role-arn "${ROLE_ARN}" \
    --query 'stateMachineArn' --output text 2>/dev/null || echo "exists")
if [ "$SM_ARN" = "exists" ]; then
    SM_ARN=$($AWS_CMD stepfunctions list-state-machines --query "stateMachines[?name=='demo-machine'].stateMachineArn" --output text 2>/dev/null)
fi
log_success "State Machine: ${SM_ARN}"
section_end

section_start "2. Execute"
EXEC_ARN=$($AWS_CMD stepfunctions start-execution \
    --state-machine-arn "${SM_ARN}" \
    --input '{"is_test": true}' \
    --query 'executionArn' --output text)
log_success "Execution: ${EXEC_ARN}"
section_end

section_start "3. Describe Execution"
sleep 1
$AWS_CMD stepfunctions describe-execution --execution-arn "${EXEC_ARN}" --output json | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f'   Status: {d[\"status\"]}')
print(f'   Output: {d.get(\"output\",\"\")}')
" 2>/dev/null
section_end

summary_box "Step Functions Complete" "Create State Machine, Execute, Describe"
