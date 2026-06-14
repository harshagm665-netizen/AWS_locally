#!/usr/bin/env bash
# ══ Smoke Test ══
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

check_floci
FAILED=0
run_test() {
    if eval "$2" &>/dev/null; then echo -e "  ${GREEN}✅ PASS${RESET}  $1";
    else echo -e "  ${RED}❌ FAIL${RESET}  $1"; FAILED=$((FAILED + 1)); fi
}
echo -e "\n  ${BOLD}Running smoke tests...${RESET}\n"
run_test "S3"          "$AWS_CMD s3 ls"
run_test "DynamoDB"    "$AWS_CMD dynamodb list-tables"
run_test "SQS"         "$AWS_CMD sqs list-queues"
run_test "SNS"         "$AWS_CMD sns list-topics"
run_test "Lambda"      "$AWS_CMD lambda list-functions"
run_test "IAM"         "$AWS_CMD iam list-users"
run_test "Secrets"     "$AWS_CMD secretsmanager list-secrets"
exit $FAILED
