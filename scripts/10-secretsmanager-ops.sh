#!/usr/bin/env bash
# ==============================================================================
#  10 — AWS Secrets Manager Operations
# ==============================================================================
#  Demonstrates the full Secrets Manager lifecycle:
#    • Create secrets (string & JSON)
#    • Retrieve secret values
#    • Update / rotate secrets
#    • Version stages
#    • List & describe secrets
#    • Delete & restore secrets
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

print_banner "AWS SECRETS MANAGER" "🔑"
check_localstack

# ══════════════════════════════════════════════════════════════════════════════
#  CREATE SECRETS
# ══════════════════════════════════════════════════════════════════════════════
section_start "1. Create Secrets"

# Database credentials (JSON)
log_step "Creating secret: app/database/credentials"
$AWS_CMD secretsmanager create-secret \
    --name "app/database/credentials" \
    --description "Production database connection credentials" \
    --secret-string '{"host":"db.example.com","port":5432,"username":"app_user","password":"S3cur3P@ssw0rd!","database":"production_db","ssl":true}' \
    --tags Key=Environment,Value=production Key=Service,Value=database \
    --output json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'   Name: {d[\"Name\"]}')
print(f'   ARN:  {d[\"ARN\"]}')
" 2>/dev/null || log_warning "Secret may already exist"
log_success "Database credentials created"

# API keys (JSON)
log_step "Creating secret: app/api-keys"
$AWS_CMD secretsmanager create-secret \
    --name "app/api-keys" \
    --description "Third-party API keys" \
    --secret-string '{"stripe_key":"sk_live_abc123","sendgrid_key":"SG.xyz789","openai_key":"sk-demo-key-12345"}' \
    --tags Key=Environment,Value=production Key=Service,Value=api \
    2>/dev/null || true
log_success "API keys created"

# Simple string secret
log_step "Creating secret: app/jwt-signing-key"
$AWS_CMD secretsmanager create-secret \
    --name "app/jwt-signing-key" \
    --description "JWT token signing key" \
    --secret-string "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.demo-signing-key" \
    2>/dev/null || true
log_success "JWT signing key created"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  LIST SECRETS
# ══════════════════════════════════════════════════════════════════════════════
section_start "2. List All Secrets"

$AWS_CMD secretsmanager list-secrets \
    --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
secrets = data.get('SecretList', [])
print(f'   {\"Name\":<35} {\"Description\":<40}')
print(f'   {\"-\"*35} {\"-\"*40}')
for s in secrets:
    name = s.get('Name', 'N/A')
    desc = s.get('Description', '')[:38]
    print(f'   {name:<35} {desc}')
print(f'\n   Total: {len(secrets)} secrets')
" 2>/dev/null

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  RETRIEVE SECRET VALUES
# ══════════════════════════════════════════════════════════════════════════════
section_start "3. Retrieve Secret Values"

log_step "Getting database credentials"
$AWS_CMD secretsmanager get-secret-value \
    --secret-id "app/database/credentials" \
    --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
secret = json.loads(data['SecretString'])
print(f'   Host:     {secret[\"host\"]}')
print(f'   Port:     {secret[\"port\"]}')
print(f'   Username: {secret[\"username\"]}')
print(f'   Password: {\"*\" * len(secret[\"password\"])} (masked)')
print(f'   Database: {secret[\"database\"]}')
print(f'   SSL:      {secret[\"ssl\"]}')
print(f'   Version:  {data.get(\"VersionId\", \"N/A\")[:12]}...')
" 2>/dev/null
log_success "Credentials retrieved"

log_step "Getting API keys (masked)"
$AWS_CMD secretsmanager get-secret-value \
    --secret-id "app/api-keys" \
    --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
secret = json.loads(data['SecretString'])
for key, val in secret.items():
    masked = val[:8] + '...' + val[-4:] if len(val) > 12 else '****'
    print(f'   {key}: {masked}')
" 2>/dev/null
log_success "API keys retrieved (masked)"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  UPDATE SECRET
# ══════════════════════════════════════════════════════════════════════════════
section_start "4. Update Secret (Rotate Password)"

log_step "Rotating database password"
$AWS_CMD secretsmanager update-secret \
    --secret-id "app/database/credentials" \
    --secret-string '{"host":"db.example.com","port":5432,"username":"app_user","password":"N3wR0t@tedP@ss!","database":"production_db","ssl":true}' \
    --output json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'   Updated: {d[\"Name\"]}')
print(f'   Version: {d.get(\"VersionId\", \"N/A\")[:12]}...')
" 2>/dev/null
log_success "Password rotated"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  DESCRIBE SECRET
# ══════════════════════════════════════════════════════════════════════════════
section_start "5. Describe Secret Metadata"

$AWS_CMD secretsmanager describe-secret \
    --secret-id "app/database/credentials" \
    --output json | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'   Name:          {d[\"Name\"]}')
print(f'   ARN:           {d[\"ARN\"]}')
print(f'   Description:   {d.get(\"Description\", \"N/A\")}')
print(f'   Last Changed:  {str(d.get(\"LastChangedDate\", \"N/A\"))[:19]}')
print(f'   Last Accessed: {str(d.get(\"LastAccessedDate\", \"N/A\"))[:19]}')
versions = d.get('VersionIdsToStages', {})
print(f'   Versions:      {len(versions)}')
for vid, stages in list(versions.items())[:3]:
    print(f'     • {vid[:12]}... → {stages}')
" 2>/dev/null

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  DELETE & SCHEDULE DELETION
# ══════════════════════════════════════════════════════════════════════════════
section_start "6. Delete Secret (with Recovery Window)"

log_step "Scheduling deletion of jwt-signing-key (7-day recovery)"
$AWS_CMD secretsmanager delete-secret \
    --secret-id "app/jwt-signing-key" \
    --recovery-window-in-days 7 \
    --output json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'   Secret: {d[\"Name\"]}')
print(f'   Deletion Date: {str(d.get(\"DeletionDate\", \"N/A\"))[:19]}')
" 2>/dev/null
log_success "Deletion scheduled"

log_step "Restoring deleted secret"
$AWS_CMD secretsmanager restore-secret \
    --secret-id "app/jwt-signing-key" 2>/dev/null || log_detail "Restore attempted"
log_success "Secret restored"

section_end

summary_box "Secrets Manager Operations Complete" \
    "Secrets: JSON credentials, API keys, string tokens" \
    "Operations: create, retrieve, update, rotate" \
    "Lifecycle: delete with recovery, restore"
