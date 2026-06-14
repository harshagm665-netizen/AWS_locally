#!/usr/bin/env bash
# ==============================================================================
#  Smoke Test — Validate All AWS Services
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

print_banner "SMOKE TEST — Service Validation" "🧪"
check_localstack

PASSED=0
FAILED=0
TOTAL=0

run_test() {
    local name="$1"
    local cmd="$2"
    TOTAL=$((TOTAL + 1))

    if eval "$cmd" &>/dev/null; then
        echo -e "  ${GREEN}✅ PASS${RESET}  ${name}"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}❌ FAIL${RESET}  ${name}"
        FAILED=$((FAILED + 1))
    fi
}

echo ""
echo -e "  ${BOLD}Running service smoke tests...${RESET}"
echo ""

# ── S3 ──
run_test "S3 — Create bucket"         "$AWS_CMD s3 mb s3://smoke-test-bucket"
run_test "S3 — List buckets"          "$AWS_CMD s3 ls"
run_test "S3 — Upload object"         "echo 'test' | $AWS_CMD s3 cp - s3://smoke-test-bucket/test.txt"
run_test "S3 — Download object"       "$AWS_CMD s3 cp s3://smoke-test-bucket/test.txt /dev/null"
run_test "S3 — Delete bucket"         "$AWS_CMD s3 rb s3://smoke-test-bucket --force"

# ── DynamoDB ──
run_test "DynamoDB — Create table"    "$AWS_CMD dynamodb create-table --table-name smoke-test --attribute-definitions AttributeName=id,AttributeType=S --key-schema AttributeName=id,KeyType=HASH --billing-mode PAY_PER_REQUEST"
run_test "DynamoDB — Put item"        "$AWS_CMD dynamodb put-item --table-name smoke-test --item '{\"id\":{\"S\":\"1\"},\"data\":{\"S\":\"test\"}}'"
run_test "DynamoDB — Get item"        "$AWS_CMD dynamodb get-item --table-name smoke-test --key '{\"id\":{\"S\":\"1\"}}'"
run_test "DynamoDB — Delete table"    "$AWS_CMD dynamodb delete-table --table-name smoke-test"

# ── SQS ──
run_test "SQS — Create queue"         "$AWS_CMD sqs create-queue --queue-name smoke-test-queue"
SMOKE_QUEUE_URL=$($AWS_CMD sqs get-queue-url --queue-name smoke-test-queue --query 'QueueUrl' --output text 2>/dev/null || echo "")
run_test "SQS — Send message"         "$AWS_CMD sqs send-message --queue-url '${SMOKE_QUEUE_URL}' --message-body 'test'"
run_test "SQS — Receive message"      "$AWS_CMD sqs receive-message --queue-url '${SMOKE_QUEUE_URL}'"
run_test "SQS — Delete queue"         "$AWS_CMD sqs delete-queue --queue-url '${SMOKE_QUEUE_URL}'"

# ── SNS ──
run_test "SNS — Create topic"         "$AWS_CMD sns create-topic --name smoke-test-topic"
SMOKE_TOPIC=$($AWS_CMD sns create-topic --name smoke-test-topic --query 'TopicArn' --output text 2>/dev/null || echo "")
run_test "SNS — Publish message"      "$AWS_CMD sns publish --topic-arn '${SMOKE_TOPIC}' --message 'test'"
run_test "SNS — Delete topic"         "$AWS_CMD sns delete-topic --topic-arn '${SMOKE_TOPIC}'"

# ── IAM ──
run_test "IAM — Create user"          "$AWS_CMD iam create-user --user-name smoke-test-user"
run_test "IAM — List users"           "$AWS_CMD iam list-users"
run_test "IAM — Delete user"          "$AWS_CMD iam delete-user --user-name smoke-test-user"

# ── Lambda ──
run_test "Lambda — List functions"    "$AWS_CMD lambda list-functions"

# ── Secrets Manager ──
run_test "Secrets — Create secret"    "$AWS_CMD secretsmanager create-secret --name smoke-test-secret --secret-string 'test123'"
run_test "Secrets — Get value"        "$AWS_CMD secretsmanager get-secret-value --secret-id smoke-test-secret"
run_test "Secrets — Delete secret"    "$AWS_CMD secretsmanager delete-secret --secret-id smoke-test-secret --force-delete-without-recovery"

# ── Kinesis ──
run_test "Kinesis — Create stream"    "$AWS_CMD kinesis create-stream --stream-name smoke-test-stream --shard-count 1"
run_test "Kinesis — List streams"     "$AWS_CMD kinesis list-streams"
run_test "Kinesis — Delete stream"    "$AWS_CMD kinesis delete-stream --stream-name smoke-test-stream"

# ── EventBridge ──
run_test "EventBridge — List buses"   "$AWS_CMD events list-event-buses"
run_test "EventBridge — Put rule"     "$AWS_CMD events put-rule --name smoke-test-rule --schedule-expression 'rate(1 hour)'"
run_test "EventBridge — Delete rule"  "$AWS_CMD events delete-rule --name smoke-test-rule"

# ── Step Functions ──
run_test "StepFunctions — List SMs"   "$AWS_CMD stepfunctions list-state-machines"

# ── EC2 ──
run_test "EC2 — Describe instances"   "$AWS_CMD ec2 describe-instances"
run_test "EC2 — Describe VPCs"        "$AWS_CMD ec2 describe-vpcs"

# ── CloudFormation ──
run_test "CloudFormation — List stacks" "$AWS_CMD cloudformation list-stacks"

# ── API Gateway ──
run_test "API Gateway — List APIs"    "$AWS_CMD apigateway get-rest-apis"

# ── Results ──
echo ""
echo -e "  ${BOLD}${CYAN}═══════════════════════════════════════════════${RESET}"
echo -e "  ${BOLD}  Results: ${GREEN}${PASSED} passed${RESET} / ${RED}${FAILED} failed${RESET} / ${TOTAL} total"
echo -e "  ${BOLD}${CYAN}═══════════════════════════════════════════════${RESET}"
echo ""

if [ $FAILED -gt 0 ]; then
    log_warning "${FAILED} tests failed — check LocalStack logs"
    exit 1
else
    log_success "All smoke tests passed!"
    exit 0
fi
