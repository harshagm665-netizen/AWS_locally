#!/usr/bin/env bash
# ==============================================================================
#  07 — AWS IAM Operations
# ==============================================================================
#  Demonstrates the full IAM lifecycle:
#    • Create users, groups, roles
#    • Attach managed & inline policies
#    • Create custom policies
#    • Access keys management
#    • Policy simulation
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

print_banner "AWS IAM — Identity & Access Management" "🔐"
check_localstack

# ══════════════════════════════════════════════════════════════════════════════
#  CREATE USERS
# ══════════════════════════════════════════════════════════════════════════════
section_start "1. Create IAM Users"

USERS=("dev-alice" "dev-bob" "ops-charlie")

for user in "${USERS[@]}"; do
    log_step "Creating user: ${user}"
    $AWS_CMD iam create-user --user-name "${user}" 2>/dev/null || true

    # Add tags
    $AWS_CMD iam tag-user --user-name "${user}" \
        --tags Key=Department,Value=Engineering Key=Environment,Value=local 2>/dev/null || true
    log_success "User created: ${user}"
done

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  CREATE GROUPS
# ══════════════════════════════════════════════════════════════════════════════
section_start "2. Create Groups & Add Members"

log_step "Creating group: developers"
$AWS_CMD iam create-group --group-name developers 2>/dev/null || true

log_step "Creating group: operations"
$AWS_CMD iam create-group --group-name operations 2>/dev/null || true

# Add users to groups
$AWS_CMD iam add-user-to-group --user-name dev-alice --group-name developers 2>/dev/null || true
$AWS_CMD iam add-user-to-group --user-name dev-bob --group-name developers 2>/dev/null || true
$AWS_CMD iam add-user-to-group --user-name ops-charlie --group-name operations 2>/dev/null || true
log_success "Users assigned to groups"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  CREATE CUSTOM POLICIES
# ══════════════════════════════════════════════════════════════════════════════
section_start "3. Create Custom IAM Policies"

# Developer policy — S3 and DynamoDB access
DEV_POLICY='{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "S3ReadWrite",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::app-*",
                "arn:aws:s3:::app-*/*"
            ]
        },
        {
            "Sid": "DynamoDBReadWrite",
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:UpdateItem",
                "dynamodb:DeleteItem",
                "dynamodb:Query",
                "dynamodb:Scan"
            ],
            "Resource": "arn:aws:dynamodb:*:*:table/*"
        },
        {
            "Sid": "LambdaDeploy",
            "Effect": "Allow",
            "Action": [
                "lambda:UpdateFunctionCode",
                "lambda:InvokeFunction",
                "lambda:GetFunction"
            ],
            "Resource": "*"
        }
    ]
}'

log_step "Creating policy: DeveloperAccess"
DEV_POLICY_ARN=$($AWS_CMD iam create-policy \
    --policy-name DeveloperAccess \
    --policy-document "$DEV_POLICY" \
    --description "Custom policy for developers — S3, DynamoDB, Lambda" \
    --query 'Policy.Arn' --output text 2>/dev/null || echo "arn:aws:iam::000000000000:policy/DeveloperAccess")
log_success "Policy ARN: ${DEV_POLICY_ARN}"

# Operations policy — Full admin for monitoring
OPS_POLICY='{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CloudWatchAccess",
            "Effect": "Allow",
            "Action": [
                "cloudwatch:*",
                "logs:*",
                "events:*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "EC2ReadOnly",
            "Effect": "Allow",
            "Action": [
                "ec2:Describe*",
                "ec2:Get*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "SecretsAccess",
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:ListSecrets"
            ],
            "Resource": "*"
        }
    ]
}'

log_step "Creating policy: OperationsAccess"
OPS_POLICY_ARN=$($AWS_CMD iam create-policy \
    --policy-name OperationsAccess \
    --policy-document "$OPS_POLICY" \
    --description "Custom policy for operations — CloudWatch, EC2, Secrets" \
    --query 'Policy.Arn' --output text 2>/dev/null || echo "arn:aws:iam::000000000000:policy/OperationsAccess")
log_success "Policy ARN: ${OPS_POLICY_ARN}"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  ATTACH POLICIES TO GROUPS
# ══════════════════════════════════════════════════════════════════════════════
section_start "4. Attach Policies to Groups"

log_step "Attaching DeveloperAccess to developers group"
$AWS_CMD iam attach-group-policy \
    --group-name developers \
    --policy-arn "${DEV_POLICY_ARN}" 2>/dev/null || true
log_success "Attached"

log_step "Attaching OperationsAccess to operations group"
$AWS_CMD iam attach-group-policy \
    --group-name operations \
    --policy-arn "${OPS_POLICY_ARN}" 2>/dev/null || true
log_success "Attached"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  CREATE ROLES
# ══════════════════════════════════════════════════════════════════════════════
section_start "5. Create IAM Roles"

EC2_TRUST='{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": {"Service": "ec2.amazonaws.com"},
        "Action": "sts:AssumeRole"
    }]
}'

log_step "Creating role: ec2-app-role"
$AWS_CMD iam create-role \
    --role-name ec2-app-role \
    --assume-role-policy-document "$EC2_TRUST" \
    --description "Role for EC2 application instances" 2>/dev/null || true
log_success "Role created: ec2-app-role"

# Attach inline policy
INLINE_POLICY='{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Action": ["s3:GetObject","sqs:*","sns:Publish"],
        "Resource": "*"
    }]
}'

$AWS_CMD iam put-role-policy \
    --role-name ec2-app-role \
    --policy-name EC2AppPermissions \
    --policy-document "$INLINE_POLICY" 2>/dev/null || true
log_success "Inline policy attached to ec2-app-role"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  ACCESS KEYS
# ══════════════════════════════════════════════════════════════════════════════
section_start "6. Access Key Management"

log_step "Creating access key for dev-alice"
KEY_RESULT=$($AWS_CMD iam create-access-key --user-name dev-alice --output json 2>/dev/null || echo '{}')
echo "$KEY_RESULT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
key = data.get('AccessKey', {})
if key:
    print(f'   Access Key ID:     {key.get(\"AccessKeyId\", \"N/A\")}')
    print(f'   Secret Key:        {key.get(\"SecretAccessKey\", \"N/A\")[:8]}...[REDACTED]')
    print(f'   Status:            {key.get(\"Status\", \"N/A\")}')
else:
    print('   Key already exists or error occurred')
" 2>/dev/null

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  LIST EVERYTHING
# ══════════════════════════════════════════════════════════════════════════════
section_start "7. IAM Summary"

log_step "Users:"
$AWS_CMD iam list-users --output json | python3 -c "
import json, sys
for u in json.load(sys.stdin).get('Users', []):
    print(f'   • {u[\"UserName\"]:20} (created: {str(u.get(\"CreateDate\",\"N/A\"))[:19]})')
" 2>/dev/null

echo ""
log_step "Groups:"
for group in developers operations; do
    MEMBERS=$($AWS_CMD iam get-group --group-name "${group}" --output json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
members = [u['UserName'] for u in d.get('Users', [])]
print(', '.join(members) if members else 'none')
" 2>/dev/null || echo "?")
    log_detail "${group}: ${MEMBERS}"
done

echo ""
log_step "Roles:"
$AWS_CMD iam list-roles --output json | python3 -c "
import json, sys
for r in json.load(sys.stdin).get('Roles', []):
    print(f'   • {r[\"RoleName\"]:30} {r.get(\"Description\",\"\")[:40]}')
" 2>/dev/null

section_end

summary_box "IAM Operations Complete" \
    "Users: create, tag, access keys" \
    "Groups: create, attach policies, add members" \
    "Roles: create with trust policy, inline policy" \
    "Policies: custom developer & operations policies"
