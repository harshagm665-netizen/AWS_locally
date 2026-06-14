#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
check_floci
CF_DIR="${SCRIPT_DIR}/../cloudformation"
for template in "${CF_DIR}"/*.yaml; do
    if $AWS_CMD cloudformation validate-template --template-body "file://${template}" &>/dev/null; then
        echo -e "  ${GREEN}✅ VALID${RESET}   $(basename "$template")"
    else
        echo -e "  ${RED}❌ INVALID${RESET} $(basename "$template")"
    fi
done
