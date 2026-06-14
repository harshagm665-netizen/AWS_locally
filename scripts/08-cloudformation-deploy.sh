#!/usr/bin/env bash
# ==============================================================================
#  08 — AWS CloudFormation Operations
# ==============================================================================
#  Demonstrates Infrastructure as Code:
#    • Validate templates
#    • Create stacks
#    • Describe stack resources
#    • Stack outputs
#    • Update stacks
#    • Stack events
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

print_banner "AWS CLOUDFORMATION — Infrastructure as Code" "🏗️"
check_localstack

CF_DIR="${SCRIPT_DIR}/../cloudformation"
STACK_NAME="demo-full-stack"

# ══════════════════════════════════════════════════════════════════════════════
#  VALIDATE TEMPLATES
# ══════════════════════════════════════════════════════════════════════════════
section_start "1. Validate CloudFormation Templates"

log_step "Validating full-stack.yaml"
$AWS_CMD cloudformation validate-template \
    --template-body "file://${CF_DIR}/full-stack.yaml" \
    --output json | python3 -c "
import json, sys
d = json.load(sys.stdin)
params = d.get('Parameters', [])
print(f'   Parameters: {len(params)}')
for p in params:
    print(f'     • {p[\"ParameterKey\"]} (default: {p.get(\"DefaultValue\", \"none\")})')
desc = d.get('Description', 'N/A')
print(f'   Description: {desc}')
" 2>/dev/null
log_success "Template valid: full-stack.yaml"

log_step "Validating networking.yaml"
$AWS_CMD cloudformation validate-template \
    --template-body "file://${CF_DIR}/networking.yaml" 2>/dev/null
log_success "Template valid: networking.yaml"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  CREATE STACK
# ══════════════════════════════════════════════════════════════════════════════
section_start "2. Create Stack: ${STACK_NAME}"

log_step "Deploying full-stack.yaml..."
$AWS_CMD cloudformation create-stack \
    --stack-name "${STACK_NAME}" \
    --template-body "file://${CF_DIR}/full-stack.yaml" \
    --parameters \
        ParameterKey=EnvironmentName,ParameterValue=demo \
        ParameterKey=ProjectName,ParameterValue=localstack-demo \
    --tags \
        Key=Environment,Value=local \
        Key=ManagedBy,Value=CloudFormation \
    --output json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'   Stack ID: {d.get(\"StackId\", \"N/A\")}')
" 2>/dev/null || log_warning "Stack may already exist"
log_success "Stack creation initiated"

# Wait for stack to complete
log_step "Waiting for stack to complete..."
sleep 3
$AWS_CMD cloudformation wait stack-create-complete \
    --stack-name "${STACK_NAME}" 2>/dev/null || log_detail "Wait completed or timed out"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  DESCRIBE STACK
# ══════════════════════════════════════════════════════════════════════════════
section_start "3. Stack Description"

$AWS_CMD cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
stacks = data.get('Stacks', [])
if stacks:
    s = stacks[0]
    print(f'   Stack Name:     {s[\"StackName\"]}')
    print(f'   Status:         {s[\"StackStatus\"]}')
    print(f'   Created:        {str(s.get(\"CreationTime\", \"N/A\"))[:19]}')
    print(f'   Description:    {s.get(\"Description\", \"N/A\")[:60]}')

    outputs = s.get('Outputs', [])
    if outputs:
        print(f'   Outputs:')
        for o in outputs:
            print(f'     • {o[\"OutputKey\"]}: {o[\"OutputValue\"]}')
" 2>/dev/null

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  LIST STACK RESOURCES
# ══════════════════════════════════════════════════════════════════════════════
section_start "4. Stack Resources"

$AWS_CMD cloudformation list-stack-resources \
    --stack-name "${STACK_NAME}" \
    --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
resources = data.get('StackResourceSummaries', [])
print(f'   {\"Logical ID\":<30} {\"Type\":<40} {\"Status\"}')
print(f'   {\"-\"*30} {\"-\"*40} {\"-\"*20}')
for r in resources:
    print(f'   {r[\"LogicalResourceId\"]:<30} {r[\"ResourceType\"]:<40} {r[\"ResourceStatus\"]}')
" 2>/dev/null

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  STACK EVENTS
# ══════════════════════════════════════════════════════════════════════════════
section_start "5. Stack Events (Latest 10)"

$AWS_CMD cloudformation describe-stack-events \
    --stack-name "${STACK_NAME}" \
    --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
events = data.get('StackEvents', [])[:10]
for e in events:
    ts = str(e.get('Timestamp', ''))[:19]
    logical = e.get('LogicalResourceId', '?')[:25]
    status = e.get('ResourceStatus', '?')
    print(f'   {ts}  {logical:<25}  {status}')
" 2>/dev/null

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  DEPLOY NETWORKING STACK
# ══════════════════════════════════════════════════════════════════════════════
section_start "6. Deploy Networking Stack"

log_step "Creating network-stack..."
$AWS_CMD cloudformation create-stack \
    --stack-name "network-stack" \
    --template-body "file://${CF_DIR}/networking.yaml" \
    --parameters \
        ParameterKey=EnvironmentName,ParameterValue=demo \
    --output json 2>/dev/null || log_warning "Stack may already exist"
log_success "Networking stack deployed"

sleep 2

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  LIST ALL STACKS
# ══════════════════════════════════════════════════════════════════════════════
section_start "7. All Stacks"

$AWS_CMD cloudformation list-stacks \
    --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
    --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
stacks = data.get('StackSummaries', [])
for s in stacks:
    print(f'   • {s[\"StackName\"]:<25} {s[\"StackStatus\"]:<25} {str(s.get(\"CreationTime\",\"\"))[:19]}')
" 2>/dev/null

section_end

summary_box "CloudFormation Operations Complete" \
    "Templates: validated full-stack.yaml + networking.yaml" \
    "Stacks: created, described, events listed" \
    "Resources: all provisioned via IaC"
