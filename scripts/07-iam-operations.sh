#!/usr/bin/env bash
# ══ 07 — AWS IAM Operations (Floci) ══
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
print_banner "AWS IAM — Identity & Access" "🔐"
check_floci

USER="demo-floci-user"
GROUP="demo-floci-group"

section_start "1. Create User & Group"
$AWS_CMD iam create-user --user-name "${USER}" 2>/dev/null || true
log_success "User: ${USER}"
$AWS_CMD iam create-group --group-name "${GROUP}" 2>/dev/null || true
log_success "Group: ${GROUP}"
$AWS_CMD iam add-user-to-group --user-name "${USER}" --group-name "${GROUP}"
log_success "Added user to group"
section_end

section_start "2. Create Policy"
POLICY_ARN=$($AWS_CMD iam create-policy --policy-name "demo-s3-readonly" \
    --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:Get*","s3:List*"],"Resource":"*"}]}' \
    --query 'Policy.Arn' --output text 2>/dev/null || echo "arn:aws:iam::000000000000:policy/demo-s3-readonly")
log_success "Policy: ${POLICY_ARN}"
section_end

section_start "3. Attach Policy"
$AWS_CMD iam attach-group-policy --group-name "${GROUP}" --policy-arn "${POLICY_ARN}"
log_success "Attached policy to group"
section_end

section_start "4. Create Access Keys"
KEYS=$($AWS_CMD iam create-access-key --user-name "${USER}" --output json)
echo "$KEYS" | python3 -c "
import json,sys
k=json.load(sys.stdin).get('AccessKey',{})
print(f'   Key ID:     {k.get(\"AccessKeyId\")}')
print(f'   Secret Key: {k.get(\"SecretAccessKey\")}')
" 2>/dev/null
section_end

section_start "5. Create Role"
ROLE_ARN=$($AWS_CMD iam create-role --role-name "demo-app-role" \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
    --query 'Role.Arn' --output text 2>/dev/null || true)
log_success "Role created: demo-app-role"
section_end

summary_box "IAM Complete" "Users, Groups, Roles, Policies, Access Keys"
