#!/usr/bin/env bash
# ══ 05 — AWS Lambda Operations (Floci) ══
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
print_banner "AWS LAMBDA — Serverless Compute" "⚡"
check_floci

FUNC="demo-hello-world"
ROLE_ARN="arn:aws:iam::000000000000:role/lambda-role"
ZIP_FILE="${SCRIPT_DIR}/../lambda/hello-world/function.zip"

section_start "1. Prepare Package"
cd "${SCRIPT_DIR}/../lambda/hello-world"
zip -q -r function.zip handler.py
cd - >/dev/null
log_success "Created function.zip"
section_end

section_start "2. Create Function"
$AWS_CMD lambda create-function \
    --function-name "${FUNC}" \
    --runtime python3.9 \
    --handler handler.lambda_handler \
    --role "${ROLE_ARN}" \
    --zip-file "fileb://${ZIP_FILE}" \
    --environment 'Variables={LOG_LEVEL=DEBUG,ENV=local}' \
    --timeout 10 \
    --memory-size 128 \
    --query 'FunctionArn' --output text 2>/dev/null || log_detail "Function may exist"
log_success "Function: ${FUNC}"
section_end

section_start "3. List Functions"
$AWS_CMD lambda list-functions --output table
section_end

section_start "4. Invoke (Synchronous)"
RES=$($AWS_CMD lambda invoke --function-name "${FUNC}" \
    --payload '{"name":"Floci User","action":"test"}' \
    --cli-binary-format raw-in-base64-out \
    /tmp/lambda-out.json --output text)
log_success "Invoke result: ${RES}"
log_detail "Output: $(cat /tmp/lambda-out.json)"
section_end

section_start "5. Invoke (Asynchronous)"
$AWS_CMD lambda invoke --function-name "${FUNC}" \
    --invocation-type Event \
    --payload '{"name":"Async User"}' \
    --cli-binary-format raw-in-base64-out \
    /tmp/lambda-async.json --output text | grep -q "202" && log_success "Async invoke queued"
section_end

section_start "6. Get Configuration"
$AWS_CMD lambda get-function-configuration --function-name "${FUNC}" --output json | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f'   Runtime: {d.get(\"Runtime\")} | Mem: {d.get(\"MemorySize\")}MB | Timeout: {d.get(\"Timeout\")}s')
print(f'   Env: {d.get(\"Environment\",{}).get(\"Variables\",{})}')
" 2>/dev/null
section_end

summary_box "Lambda Complete" "Deploy, sync/async invoke, env vars, config"
