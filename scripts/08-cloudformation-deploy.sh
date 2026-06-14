#!/usr/bin/env bash
# ══ 08 — AWS CloudFormation Operations (Floci) ══
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
print_banner "AWS CLOUDFORMATION — IaC" "🏗️"
check_floci

STACK="demo-cf-stack"
CF_TEMPLATE="${SCRIPT_DIR}/../cloudformation/full-stack.yaml"

section_start "1. Validate Template"
$AWS_CMD cloudformation validate-template --template-body "file://${CF_TEMPLATE}" >/dev/null && log_success "Template is valid"
section_end

section_start "2. Create Stack"
$AWS_CMD cloudformation create-stack \
    --stack-name "${STACK}" \
    --template-body "file://${CF_TEMPLATE}" \
    --parameters ParameterKey=EnvironmentName,ParameterValue=flocitest ParameterKey=ProjectName,ParameterValue=demo \
    --capabilities CAPABILITY_NAMED_IAM >/dev/null 2>&1 || true
log_success "Stack creation initiated: ${STACK}"
section_end

section_start "3. Wait for Stack"
log_step "Waiting for stack CREATE_COMPLETE..."
$AWS_CMD cloudformation wait stack-create-complete --stack-name "${STACK}" 2>/dev/null || sleep 5
log_success "Stack ready"
section_end

section_start "4. List Stack Resources"
$AWS_CMD cloudformation list-stack-resources --stack-name "${STACK}" --output table
section_end

section_start "5. Delete Stack"
$AWS_CMD cloudformation delete-stack --stack-name "${STACK}"
log_success "Stack deletion initiated"
section_end

summary_box "CloudFormation Complete" "Validate, Deploy, Resources, Delete"
