#!/usr/bin/env bash
# ══ 10 — AWS Secrets Manager Operations (Floci) ══
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
print_banner "AWS SECRETS MANAGER" "🔑"
check_floci

SECRET_NAME="demo-app/db-credentials"

section_start "1. Create Secret"
$AWS_CMD secretsmanager create-secret \
    --name "${SECRET_NAME}" \
    --description "Database credentials" \
    --secret-string '{"username":"admin","password":"SuperSecretPassword123"}' \
    --query 'ARN' --output text 2>/dev/null || log_detail "Secret exists"
log_success "Secret created: ${SECRET_NAME}"
section_end

section_start "2. Retrieve Secret"
$AWS_CMD secretsmanager get-secret-value --secret-id "${SECRET_NAME}" --output json | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f'   Secret String: {d[\"SecretString\"]}')
" 2>/dev/null
section_end

section_start "3. Update Secret"
$AWS_CMD secretsmanager put-secret-value \
    --secret-id "${SECRET_NAME}" \
    --secret-string '{"username":"admin","password":"NewPassword456"}' >/dev/null
log_success "Secret updated"
section_end

section_start "4. Delete Secret"
$AWS_CMD secretsmanager delete-secret --secret-id "${SECRET_NAME}" --force-delete-without-recovery >/dev/null
log_success "Secret deleted"
section_end

summary_box "Secrets Manager Complete" "Create, Get, Update, Delete"
