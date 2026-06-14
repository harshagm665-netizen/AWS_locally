#!/usr/bin/env bash
# ==============================================================================
#  09 — Amazon EC2 Operations
# ==============================================================================
#  Demonstrates EC2 lifecycle (LocalStack simulates EC2 as Docker containers):
#    • Security Groups (create, configure rules)
#    • Key Pairs
#    • Run / Describe / Stop / Terminate instances
#    • Tags and filtering
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

print_banner "AMAZON EC2 — Elastic Compute Cloud" "💻"
check_localstack

# ══════════════════════════════════════════════════════════════════════════════
#  CREATE KEY PAIR
# ══════════════════════════════════════════════════════════════════════════════
section_start "1. Create Key Pair"

log_step "Creating key pair: demo-keypair"
$AWS_CMD ec2 create-key-pair \
    --key-name demo-keypair \
    --query 'KeyFingerprint' --output text 2>/dev/null || log_detail "Key pair may already exist"
log_success "Key pair created: demo-keypair"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  CREATE SECURITY GROUP
# ══════════════════════════════════════════════════════════════════════════════
section_start "2. Create Security Groups"

# Get default VPC
VPC_ID=$($AWS_CMD ec2 describe-vpcs \
    --filters Name=isDefault,Values=true \
    --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "vpc-default")

log_step "Creating security group: web-server-sg"
WEB_SG_ID=$($AWS_CMD ec2 create-security-group \
    --group-name web-server-sg \
    --description "Allow HTTP, HTTPS, and SSH traffic" \
    --vpc-id "${VPC_ID}" \
    --query 'GroupId' --output text 2>/dev/null || echo "sg-existing")
log_success "Security Group: ${WEB_SG_ID}"

# Add inbound rules
log_step "Adding inbound rules"
$AWS_CMD ec2 authorize-security-group-ingress \
    --group-id "${WEB_SG_ID}" \
    --ip-permissions \
        'IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=0.0.0.0/0,Description="SSH Access"}]' \
        'IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0,Description="HTTP Access"}]' \
        'IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0,Description="HTTPS Access"}]' \
    2>/dev/null || log_detail "Rules may already exist"
log_success "Ingress rules added (SSH, HTTP, HTTPS)"

# App security group
log_step "Creating security group: app-server-sg"
APP_SG_ID=$($AWS_CMD ec2 create-security-group \
    --group-name app-server-sg \
    --description "Application server — internal only" \
    --vpc-id "${VPC_ID}" \
    --query 'GroupId' --output text 2>/dev/null || echo "sg-existing")

$AWS_CMD ec2 authorize-security-group-ingress \
    --group-id "${APP_SG_ID}" \
    --ip-permissions \
        "IpProtocol=tcp,FromPort=8080,ToPort=8080,UserIdGroupPairs=[{GroupId=${WEB_SG_ID},Description=\"From web tier\"}]" \
    2>/dev/null || true
log_success "App Security Group: ${APP_SG_ID}"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  RUN INSTANCES
# ══════════════════════════════════════════════════════════════════════════════
section_start "3. Launch EC2 Instances"

log_step "Launching web server instance"
WEB_INSTANCE_ID=$($AWS_CMD ec2 run-instances \
    --image-id ami-024f768332f080c22 \
    --instance-type t3.micro \
    --key-name demo-keypair \
    --security-group-ids "${WEB_SG_ID}" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=web-server-01},{Key=Environment,Value=demo},{Key=Tier,Value=web}]' \
    --query 'Instances[0].InstanceId' --output text 2>/dev/null || echo "i-demo")
log_success "Web Instance: ${WEB_INSTANCE_ID}"

log_step "Launching app server instance"
APP_INSTANCE_ID=$($AWS_CMD ec2 run-instances \
    --image-id ami-024f768332f080c22 \
    --instance-type t3.small \
    --key-name demo-keypair \
    --security-group-ids "${APP_SG_ID}" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=app-server-01},{Key=Environment,Value=demo},{Key=Tier,Value=app}]' \
    --query 'Instances[0].InstanceId' --output text 2>/dev/null || echo "i-demo")
log_success "App Instance: ${APP_INSTANCE_ID}"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  DESCRIBE INSTANCES
# ══════════════════════════════════════════════════════════════════════════════
section_start "4. Describe Instances"

$AWS_CMD ec2 describe-instances \
    --filters "Name=tag:Environment,Values=demo" \
    --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for r in data.get('Reservations', []):
    for i in r.get('Instances', []):
        name = 'N/A'
        for tag in i.get('Tags', []):
            if tag['Key'] == 'Name':
                name = tag['Value']
        print(f'   • {name:<20} {i[\"InstanceId\"]:<20} {i[\"InstanceType\"]:<12} {i[\"State\"][\"Name\"]}')
" 2>/dev/null

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  DESCRIBE SECURITY GROUPS
# ══════════════════════════════════════════════════════════════════════════════
section_start "5. Security Groups Summary"

$AWS_CMD ec2 describe-security-groups \
    --group-names web-server-sg app-server-sg \
    --output json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for sg in data.get('SecurityGroups', []):
    print(f'   {sg[\"GroupName\"]} ({sg[\"GroupId\"]})')
    print(f'   Description: {sg[\"Description\"]}')
    ingress = sg.get('IpPermissions', [])
    for rule in ingress:
        proto = rule.get('IpProtocol', 'all')
        from_p = rule.get('FromPort', '*')
        to_p = rule.get('ToPort', '*')
        sources = [r['CidrIp'] for r in rule.get('IpRanges', [])]
        groups = [g.get('GroupId', '?') for g in rule.get('UserIdGroupPairs', [])]
        src = ', '.join(sources + groups) or 'any'
        print(f'     Inbound: {proto} {from_p}-{to_p} from {src}')
    print()
" 2>/dev/null || log_detail "Security groups described"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  STOP & TERMINATE
# ══════════════════════════════════════════════════════════════════════════════
section_start "6. Stop & Terminate Instances"

if [ "${WEB_INSTANCE_ID}" != "i-demo" ]; then
    log_step "Stopping web server: ${WEB_INSTANCE_ID}"
    $AWS_CMD ec2 stop-instances --instance-ids "${WEB_INSTANCE_ID}" 2>/dev/null || true
    log_success "Instance stopped"

    log_step "Terminating app server: ${APP_INSTANCE_ID}"
    $AWS_CMD ec2 terminate-instances --instance-ids "${APP_INSTANCE_ID}" 2>/dev/null || true
    log_success "Instance terminated"
else
    log_detail "Skipping lifecycle demo (simulated IDs)"
fi

section_end

summary_box "EC2 Operations Complete" \
    "Key Pairs: create" \
    "Security Groups: web-tier + app-tier with rules" \
    "Instances: launch, describe, stop, terminate" \
    "Tags: Name, Environment, Tier"
