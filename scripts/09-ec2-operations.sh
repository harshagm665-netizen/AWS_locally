#!/usr/bin/env bash
# ══ 09 — Amazon EC2 Operations (Floci) ══
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
print_banner "AMAZON EC2 — Elastic Compute" "💻"
check_floci

# EC2 relies on Docker socket in Floci to spin up real containers
if [ ! -S /var/run/docker.sock ] && ! docker info &>/dev/null; then
    log_warning "Docker socket not accessible. EC2 may not work fully."
fi

section_start "1. Create Key Pair"
$AWS_CMD ec2 create-key-pair --key-name "floci-key" --query 'KeyMaterial' --output text > /tmp/floci-key.pem 2>/dev/null || true
chmod 400 /tmp/floci-key.pem
log_success "Key pair: floci-key created"
section_end

section_start "2. Create Security Group"
VPC=$($AWS_CMD ec2 describe-vpcs --query 'Vpcs[0].VpcId' --output text)
SG_ID=$($AWS_CMD ec2 create-security-group --group-name "floci-web-sg" --description "Web SG" --vpc-id "${VPC}" --query 'GroupId' --output text 2>/dev/null || echo "sg-exists")
if [ "$SG_ID" = "sg-exists" ]; then
    SG_ID=$($AWS_CMD ec2 describe-security-groups --group-names "floci-web-sg" --query 'SecurityGroups[0].GroupId' --output text)
else
    $AWS_CMD ec2 authorize-security-group-ingress --group-id "${SG_ID}" --protocol tcp --port 80 --cidr 0.0.0.0/0 2>/dev/null || true
fi
log_success "Security Group: ${SG_ID} (Port 80 open)"
section_end

section_start "3. Run Instance"
AMI="ami-0ff8a91507f77f867" # standard amazon linux 2 ami ID
log_step "Launching instance..."
INSTANCE_ID=$($AWS_CMD ec2 run-instances \
    --image-id "${AMI}" \
    --count 1 \
    --instance-type t2.micro \
    --key-name "floci-key" \
    --security-group-ids "${SG_ID}" \
    --query 'Instances[0].InstanceId' --output text)
log_success "Instance: ${INSTANCE_ID}"
section_end

section_start "4. Describe Instance"
sleep 2
$AWS_CMD ec2 describe-instances --instance-ids "${INSTANCE_ID}" --output json | python3 -c "
import json,sys
i=json.load(sys.stdin)['Reservations'][0]['Instances'][0]
print(f'   ID:    {i[\"InstanceId\"]}')
print(f'   Type:  {i[\"InstanceType\"]}')
print(f'   State: {i[\"State\"][\"Name\"]}')
print(f'   IP:    {i.get(\"PrivateIpAddress\", \"N/A\")}')
" 2>/dev/null
section_end

section_start "5. Terminate Instance"
$AWS_CMD ec2 terminate-instances --instance-ids "${INSTANCE_ID}" >/dev/null
log_success "Terminated ${INSTANCE_ID}"
section_end

summary_box "EC2 Complete" "Key Pairs, Security Groups, Run/Terminate Instances"
