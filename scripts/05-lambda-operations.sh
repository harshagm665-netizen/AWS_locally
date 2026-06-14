#!/usr/bin/env bash
# ==============================================================================
#  05 — AWS Lambda Operations
# ==============================================================================
#  Demonstrates the full Lambda lifecycle:
#    • Package and create functions
#    • Invoke (sync & async)
#    • Update function code
#    • Environment variables
#    • List and describe functions
#    • View logs
#    • Create function aliases & versions
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

print_banner "AWS LAMBDA — Serverless Functions" "⚡"
check_localstack

LAMBDA_DIR="${SCRIPT_DIR}/../lambda"
ROLE_ARN="arn:aws:iam::000000000000:role/lambda-execution-role"

# ══════════════════════════════════════════════════════════════════════════════
#  CREATE IAM ROLE FOR LAMBDA
# ══════════════════════════════════════════════════════════════════════════════
section_start "1. Create Lambda Execution Role"

TRUST_POLICY='{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": {"Service": "lambda.amazonaws.com"},
        "Action": "sts:AssumeRole"
    }]
}'

log_step "Creating IAM role: lambda-execution-role"
$AWS_CMD iam create-role \
    --role-name lambda-execution-role \
    --assume-role-policy-document "$TRUST_POLICY" 2>/dev/null || true

$AWS_CMD iam attach-role-policy \
    --role-name lambda-execution-role \
    --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" 2>/dev/null || true

ROLE_ARN=$($AWS_CMD iam get-role --role-name lambda-execution-role \
    --query 'Role.Arn' --output text 2>/dev/null || echo "$ROLE_ARN")
log_success "Role ARN: ${ROLE_ARN}"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  PACKAGE LAMBDA FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════
section_start "2. Package Lambda Functions"

TMPDIR=$(mktemp -d)

# Package hello-world
log_step "Packaging: hello-world"
(cd "${LAMBDA_DIR}/hello-world" && zip -j "${TMPDIR}/hello-world.zip" handler.py 2>/dev/null)
log_success "Created: hello-world.zip"

# Package api-processor
log_step "Packaging: api-processor"
(cd "${LAMBDA_DIR}/api-processor" && zip -j "${TMPDIR}/api-processor.zip" handler.py 2>/dev/null)
log_success "Created: api-processor.zip"

# Package event-processor
log_step "Packaging: event-processor"
(cd "${LAMBDA_DIR}/event-processor" && zip -j "${TMPDIR}/event-processor.zip" handler.py 2>/dev/null)
log_success "Created: event-processor.zip"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  CREATE FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════
section_start "3. Create Lambda Functions"

# ── hello-world ──
log_step "Creating function: hello-world"
$AWS_CMD lambda create-function \
    --function-name hello-world \
    --runtime python3.12 \
    --handler handler.handler \
    --role "${ROLE_ARN}" \
    --zip-file "fileb://${TMPDIR}/hello-world.zip" \
    --timeout 30 \
    --memory-size 128 \
    --environment '{"Variables":{"ENVIRONMENT":"local","LOG_LEVEL":"INFO"}}' \
    --description "Hello World Lambda — LocalStack Demo" \
    --output json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'   Function: {d[\"FunctionName\"]}')
print(f'   ARN:      {d[\"FunctionArn\"]}')
print(f'   Runtime:  {d[\"Runtime\"]}')
print(f'   Memory:   {d[\"MemorySize\"]} MB')
" 2>/dev/null || log_warning "Function may already exist — updating..."

# Update if already exists
$AWS_CMD lambda update-function-code \
    --function-name hello-world \
    --zip-file "fileb://${TMPDIR}/hello-world.zip" 2>/dev/null || true
log_success "Function ready: hello-world"

# ── api-processor ──
log_step "Creating function: api-processor"
$AWS_CMD lambda create-function \
    --function-name api-processor \
    --runtime python3.12 \
    --handler handler.handler \
    --role "${ROLE_ARN}" \
    --zip-file "fileb://${TMPDIR}/api-processor.zip" \
    --timeout 30 \
    --memory-size 256 \
    --environment '{"Variables":{"ENVIRONMENT":"local","LOG_LEVEL":"DEBUG"}}' \
    --description "API Gateway Processor — LocalStack Demo" 2>/dev/null || \
$AWS_CMD lambda update-function-code \
    --function-name api-processor \
    --zip-file "fileb://${TMPDIR}/api-processor.zip" 2>/dev/null || true
log_success "Function ready: api-processor"

# ── event-processor ──
log_step "Creating function: event-processor"
$AWS_CMD lambda create-function \
    --function-name event-processor \
    --runtime python3.12 \
    --handler handler.handler \
    --role "${ROLE_ARN}" \
    --zip-file "fileb://${TMPDIR}/event-processor.zip" \
    --timeout 60 \
    --memory-size 256 \
    --environment '{"Variables":{"ENVIRONMENT":"local","LOG_LEVEL":"INFO"}}' \
    --description "Event Processor (SQS/SNS) — LocalStack Demo" 2>/dev/null || \
$AWS_CMD lambda update-function-code \
    --function-name event-processor \
    --zip-file "fileb://${TMPDIR}/event-processor.zip" 2>/dev/null || true
log_success "Function ready: event-processor"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  LIST FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════
section_start "4. List Functions"

$AWS_CMD lambda list-functions --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
funcs = data.get('Functions', [])
print(f'   {\"Function\":<25} {\"Runtime\":<15} {\"Memory\":<10} {\"Timeout\"}')
print(f'   {\"-\"*25} {\"-\"*15} {\"-\"*10} {\"-\"*10}')
for f in funcs:
    print(f'   {f[\"FunctionName\"]:<25} {f.get(\"Runtime\",\"N/A\"):<15} {f.get(\"MemorySize\",\"?\"):<10} {f.get(\"Timeout\",\"?\")}s')
" 2>/dev/null

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  INVOKE — SYNCHRONOUS
# ══════════════════════════════════════════════════════════════════════════════
section_start "5. Invoke — Synchronous (RequestResponse)"

log_step "Invoking hello-world"
RESPONSE=$($AWS_CMD lambda invoke \
    --function-name hello-world \
    --payload '{"source":"cli-demo","action":"greet"}' \
    --cli-binary-format raw-in-base64-out \
    "${TMPDIR}/hello-response.json" \
    --output json 2>/dev/null)

echo "$RESPONSE" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'   Status Code: {d.get(\"StatusCode\", \"?\")}')
print(f'   Executed Version: {d.get(\"ExecutedVersion\", \"\$LATEST\")}')
" 2>/dev/null

log_step "Response payload:"
python3 -m json.tool "${TMPDIR}/hello-response.json" 2>/dev/null | head -20 | sed 's/^/   /'
log_success "Synchronous invocation complete"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  INVOKE — ASYNC
# ══════════════════════════════════════════════════════════════════════════════
section_start "6. Invoke — Asynchronous (Event)"

log_step "Invoking event-processor asynchronously"
$AWS_CMD lambda invoke \
    --function-name event-processor \
    --invocation-type Event \
    --payload '{"task":"async_job","priority":"high"}' \
    --cli-binary-format raw-in-base64-out \
    "${TMPDIR}/async-response.json" \
    --output json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'   Status: {d.get(\"StatusCode\", \"?\")} (202 = accepted)')
" 2>/dev/null
log_success "Async invocation accepted"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  UPDATE ENVIRONMENT VARIABLES
# ══════════════════════════════════════════════════════════════════════════════
section_start "7. Update Environment Variables"

log_step "Updating hello-world environment"
$AWS_CMD lambda update-function-configuration \
    --function-name hello-world \
    --environment '{"Variables":{"ENVIRONMENT":"staging","LOG_LEVEL":"DEBUG","FEATURE_FLAG_NEW_UI":"true"}}' \
    --output json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
env = d.get('Environment', {}).get('Variables', {})
for k, v in env.items():
    print(f'   {k} = {v}')
" 2>/dev/null
log_success "Environment updated"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  FUNCTION DETAILS
# ══════════════════════════════════════════════════════════════════════════════
section_start "8. Function Configuration"

$AWS_CMD lambda get-function-configuration \
    --function-name hello-world \
    --output json | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'   Name:        {d[\"FunctionName\"]}')
print(f'   ARN:         {d[\"FunctionArn\"]}')
print(f'   Runtime:     {d.get(\"Runtime\", \"N/A\")}')
print(f'   Handler:     {d[\"Handler\"]}')
print(f'   Memory:      {d[\"MemorySize\"]} MB')
print(f'   Timeout:     {d[\"Timeout\"]}s')
print(f'   Code Size:   {d.get(\"CodeSize\", 0)} bytes')
print(f'   Description: {d.get(\"Description\", \"\")}')
print(f'   Last Modified: {d.get(\"LastModified\", \"N/A\")}')
" 2>/dev/null

section_end

# ── Cleanup temp ──
rm -rf "${TMPDIR}"

summary_box "Lambda Operations Complete" \
    "Functions: create, invoke (sync/async), update" \
    "Config: env vars, memory, timeout" \
    "Deployed: hello-world, api-processor, event-processor"
