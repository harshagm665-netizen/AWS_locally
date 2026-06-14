#!/usr/bin/env bash
# ══ Run All AWS Service Demonstrations ══
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║${RESET}  🚀  ${BOLD}${WHITE}Floci — Full Service Demonstration${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════╝${RESET}"

check_floci
SCRIPTS=(
    "00-health-check.sh" "01-s3-operations.sh" "02-dynamodb-operations.sh"
    "03-sqs-operations.sh" "04-sns-operations.sh" "05-lambda-operations.sh"
    "06-apigateway-operations.sh" "07-iam-operations.sh" "08-cloudformation-deploy.sh"
    "09-ec2-operations.sh" "10-secretsmanager-ops.sh" "11-stepfunctions-ops.sh"
    "12-kinesis-operations.sh" "13-eventbridge-ops.sh"
)

PASSED=0; FAILED=0
for SCRIPT in "${SCRIPTS[@]}"; do
    echo -e "\n${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}  Running: ${SCRIPT}${RESET}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    if bash "${SCRIPT_DIR}/${SCRIPT}"; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
done

echo -e "\n  ${GREEN}Passed: ${PASSED} ${RESET} | ${RED}Failed: ${FAILED}${RESET}\n"
exit $FAILED
