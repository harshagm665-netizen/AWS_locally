#!/usr/bin/env bash
# ==============================================================================
#  Run All AWS Service Demonstrations
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║${RESET}  🚀  ${BOLD}${WHITE}AWS LocalStack — Full Service Demonstration${RESET}"
echo -e "${BOLD}${CYAN}║${RESET}  ${DIM}Running all 14 service scripts sequentially${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
echo ""

check_localstack

SCRIPTS=(
    "00-health-check.sh"
    "01-s3-operations.sh"
    "02-dynamodb-operations.sh"
    "03-sqs-operations.sh"
    "04-sns-operations.sh"
    "05-lambda-operations.sh"
    "06-apigateway-operations.sh"
    "07-iam-operations.sh"
    "08-cloudformation-deploy.sh"
    "09-ec2-operations.sh"
    "10-secretsmanager-ops.sh"
    "11-stepfunctions-ops.sh"
    "12-kinesis-operations.sh"
    "13-eventbridge-ops.sh"
)

TOTAL=${#SCRIPTS[@]}
PASSED=0
FAILED=0
FAILED_LIST=()

for i in "${!SCRIPTS[@]}"; do
    SCRIPT="${SCRIPTS[$i]}"
    NUM=$((i + 1))
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}  [${NUM}/${TOTAL}] Running: ${SCRIPT}${RESET}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    if bash "${SCRIPT_DIR}/${SCRIPT}"; then
        PASSED=$((PASSED + 1))
        echo -e "${GREEN}${ICON_SUCCESS}  [${NUM}/${TOTAL}] PASSED: ${SCRIPT}${RESET}"
    else
        FAILED=$((FAILED + 1))
        FAILED_LIST+=("${SCRIPT}")
        echo -e "${RED}${ICON_ERROR}  [${NUM}/${TOTAL}] FAILED: ${SCRIPT}${RESET}"
    fi
done

# ── Final Report ──
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║${RESET}  📊  ${BOLD}${WHITE}Execution Report${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${GREEN}${ICON_SUCCESS}  Passed:  ${PASSED}/${TOTAL}${RESET}"
echo -e "  ${RED}${ICON_ERROR}  Failed:  ${FAILED}/${TOTAL}${RESET}"

if [ ${#FAILED_LIST[@]} -gt 0 ]; then
    echo ""
    echo -e "  ${RED}Failed scripts:${RESET}"
    for f in "${FAILED_LIST[@]}"; do
        echo -e "    ${RED}• ${f}${RESET}"
    done
fi

echo ""
exit $FAILED
