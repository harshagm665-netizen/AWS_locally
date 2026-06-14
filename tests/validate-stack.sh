#!/usr/bin/env bash
# ==============================================================================
#  Validate CloudFormation Templates
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

print_banner "CLOUDFORMATION VALIDATION" "✅"
check_localstack

CF_DIR="${SCRIPT_DIR}/../cloudformation"
PASSED=0
FAILED=0

validate_template() {
    local file="$1"
    local name=$(basename "$file")

    if $AWS_CMD cloudformation validate-template \
        --template-body "file://${file}" &>/dev/null; then
        echo -e "  ${GREEN}✅ VALID${RESET}   ${name}"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}❌ INVALID${RESET} ${name}"
        FAILED=$((FAILED + 1))
    fi
}

echo ""
echo -e "  ${BOLD}Validating templates in cloudformation/...${RESET}"
echo ""

for template in "${CF_DIR}"/*.yaml "${CF_DIR}"/*.yml 2>/dev/null; do
    [ -f "$template" ] && validate_template "$template"
done

echo ""
echo -e "  ${BOLD}Results: ${GREEN}${PASSED} valid${RESET} / ${RED}${FAILED} invalid${RESET}"
echo ""

exit $FAILED
