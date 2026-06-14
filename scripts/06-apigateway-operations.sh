#!/usr/bin/env bash
# ==============================================================================
#  06 — Amazon API Gateway Operations
# ==============================================================================
#  Demonstrates the full API Gateway lifecycle:
#    • Create REST API
#    • Define resources & methods (GET, POST, PUT, DELETE)
#    • Lambda proxy integration
#    • Deploy to stage
#    • Test endpoints with curl
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

print_banner "AMAZON API GATEWAY — REST API" "🌐"
check_localstack

API_NAME="demo-rest-api"

# ══════════════════════════════════════════════════════════════════════════════
#  ENSURE LAMBDA EXISTS
# ══════════════════════════════════════════════════════════════════════════════
section_start "1. Verify Lambda Function"

# Check if api-processor Lambda exists; if not, create it
if ! $AWS_CMD lambda get-function --function-name api-processor &>/dev/null; then
    log_warning "api-processor Lambda not found — run 05-lambda-operations.sh first"
    log_step "Creating a minimal api-processor Lambda..."
    TMPDIR=$(mktemp -d)
    LAMBDA_DIR="${SCRIPT_DIR}/../lambda"
    (cd "${LAMBDA_DIR}/api-processor" && zip -j "${TMPDIR}/api-processor.zip" handler.py 2>/dev/null)

    $AWS_CMD iam create-role \
        --role-name lambda-execution-role \
        --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' 2>/dev/null || true

    ROLE_ARN=$($AWS_CMD iam get-role --role-name lambda-execution-role --query 'Role.Arn' --output text 2>/dev/null)

    $AWS_CMD lambda create-function \
        --function-name api-processor \
        --runtime python3.12 \
        --handler handler.handler \
        --role "${ROLE_ARN}" \
        --zip-file "fileb://${TMPDIR}/api-processor.zip" \
        --timeout 30 --memory-size 256 2>/dev/null || true
    rm -rf "${TMPDIR}"
fi

LAMBDA_ARN=$($AWS_CMD lambda get-function \
    --function-name api-processor \
    --query 'Configuration.FunctionArn' --output text)
log_success "Lambda ARN: ${LAMBDA_ARN}"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  CREATE REST API
# ══════════════════════════════════════════════════════════════════════════════
section_start "2. Create REST API"

log_step "Creating REST API: ${API_NAME}"
API_ID=$($AWS_CMD apigateway create-rest-api \
    --name "${API_NAME}" \
    --description "LocalStack Demo REST API — Full CRUD with Lambda Proxy" \
    --query 'id' --output text)
log_success "API ID: ${API_ID}"

# Get root resource ID
ROOT_ID=$($AWS_CMD apigateway get-resources \
    --rest-api-id "${API_ID}" \
    --query 'items[?path==`/`].id' --output text)
log_detail "Root Resource ID: ${ROOT_ID}"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  CREATE RESOURCES
# ══════════════════════════════════════════════════════════════════════════════
section_start "3. Create API Resources"

# /health
log_step "Creating resource: /health"
HEALTH_ID=$($AWS_CMD apigateway create-resource \
    --rest-api-id "${API_ID}" \
    --parent-id "${ROOT_ID}" \
    --path-part "health" \
    --query 'id' --output text)
log_success "/health → ${HEALTH_ID}"

# /items
log_step "Creating resource: /items"
ITEMS_ID=$($AWS_CMD apigateway create-resource \
    --rest-api-id "${API_ID}" \
    --parent-id "${ROOT_ID}" \
    --path-part "items" \
    --query 'id' --output text)
log_success "/items → ${ITEMS_ID}"

# /items/{id}
log_step "Creating resource: /items/{id}"
ITEM_ID=$($AWS_CMD apigateway create-resource \
    --rest-api-id "${API_ID}" \
    --parent-id "${ITEMS_ID}" \
    --path-part "{id}" \
    --query 'id' --output text)
log_success "/items/{id} → ${ITEM_ID}"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  DEFINE METHODS & INTEGRATIONS
# ══════════════════════════════════════════════════════════════════════════════
section_start "4. Configure Methods & Lambda Integrations"

INTEGRATION_URI="arn:aws:apigateway:${AWS_DEFAULT_REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations"

# Helper function to add method + integration
setup_method() {
    local resource_id="$1"
    local http_method="$2"
    local path_label="$3"

    log_step "  ${http_method} ${path_label}"

    # Create method
    $AWS_CMD apigateway put-method \
        --rest-api-id "${API_ID}" \
        --resource-id "${resource_id}" \
        --http-method "${http_method}" \
        --authorization-type "NONE" 2>/dev/null || true

    # Create Lambda proxy integration
    $AWS_CMD apigateway put-integration \
        --rest-api-id "${API_ID}" \
        --resource-id "${resource_id}" \
        --http-method "${http_method}" \
        --type AWS_PROXY \
        --integration-http-method POST \
        --uri "${INTEGRATION_URI}" 2>/dev/null || true
}

# /health  → GET
setup_method "${HEALTH_ID}" "GET" "/health"

# /items   → GET, POST
setup_method "${ITEMS_ID}" "GET" "/items"
setup_method "${ITEMS_ID}" "POST" "/items"

# /items/{id}  → GET, PUT, DELETE
setup_method "${ITEM_ID}" "GET" "/items/{id}"
setup_method "${ITEM_ID}" "PUT" "/items/{id}"
setup_method "${ITEM_ID}" "DELETE" "/items/{id}"

log_success "All methods and integrations configured"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  DEPLOY API
# ══════════════════════════════════════════════════════════════════════════════
section_start "5. Deploy API to Stage"

log_step "Creating deployment to 'dev' stage"
DEPLOYMENT_ID=$($AWS_CMD apigateway create-deployment \
    --rest-api-id "${API_ID}" \
    --stage-name dev \
    --stage-description "Development Stage" \
    --description "Initial deployment" \
    --query 'id' --output text)
log_success "Deployment ID: ${DEPLOYMENT_ID}"

BASE_URL="${AWS_ENDPOINT}/restapis/${API_ID}/dev/_user_request_"
log_info "Base URL: ${BASE_URL}"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  TEST ENDPOINTS
# ══════════════════════════════════════════════════════════════════════════════
section_start "6. Test API Endpoints"

log_step "GET /health"
curl -s "${BASE_URL}/health" | python3 -m json.tool 2>/dev/null | sed 's/^/   /' || log_detail "Response received"
echo ""

log_step "POST /items — Create item"
CREATE_RESPONSE=$(curl -s -X POST "${BASE_URL}/items" \
    -H "Content-Type: application/json" \
    -d '{"name":"LocalStack Widget","description":"A demo product","price":29.99}')
echo "$CREATE_RESPONSE" | python3 -m json.tool 2>/dev/null | sed 's/^/   /' || echo "   $CREATE_RESPONSE"
echo ""

log_step "GET /items — List all items"
curl -s "${BASE_URL}/items" | python3 -m json.tool 2>/dev/null | sed 's/^/   /' || log_detail "Response received"
echo ""

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  LIST API DETAILS
# ══════════════════════════════════════════════════════════════════════════════
section_start "7. API Configuration"

$AWS_CMD apigateway get-rest-api \
    --rest-api-id "${API_ID}" \
    --output json | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'   Name:        {d[\"name\"]}')
print(f'   ID:          {d[\"id\"]}')
print(f'   Description: {d.get(\"description\", \"N/A\")}')
print(f'   Created:     {d.get(\"createdDate\", \"N/A\")}')
" 2>/dev/null

echo ""
log_step "Resources & Methods:"
$AWS_CMD apigateway get-resources \
    --rest-api-id "${API_ID}" \
    --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for r in data['items']:
    path = r.get('path', '/')
    methods = list(r.get('resourceMethods', {}).keys())
    methods_str = ', '.join(methods) if methods else 'none'
    print(f'   {path:<20} [{methods_str}]')
" 2>/dev/null

section_end

summary_box "API Gateway Operations Complete" \
    "REST API: create, resources, methods" \
    "Integration: Lambda Proxy" \
    "Deployment: dev stage" \
    "Base URL: ${BASE_URL}"
