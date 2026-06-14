#!/usr/bin/env bash
# ══ 06 — Amazon API Gateway Operations (Floci) ══
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
print_banner "API GATEWAY — REST APIs" "🌐"
check_floci

section_start "1. Create REST API"
API_ID=$($AWS_CMD apigateway create-rest-api --name "demo-api" --description "Demo API via Floci" --query 'id' --output text)
log_success "API ID: ${API_ID}"
ROOT_ID=$($AWS_CMD apigateway get-resources --rest-api-id "${API_ID}" --query 'items[0].id' --output text)
section_end

section_start "2. Create Resource (/items)"
RES_ID=$($AWS_CMD apigateway create-resource --rest-api-id "${API_ID}" --parent-id "${ROOT_ID}" --path-part "items" --query 'id' --output text)
log_success "Resource ID: ${RES_ID} (/items)"
section_end

section_start "3. Create Method (GET)"
$AWS_CMD apigateway put-method --rest-api-id "${API_ID}" --resource-id "${RES_ID}" \
    --http-method GET --authorization-type "NONE" >/dev/null
log_success "Method: GET"
section_end

section_start "4. Setup Mock Integration"
$AWS_CMD apigateway put-integration --rest-api-id "${API_ID}" --resource-id "${RES_ID}" \
    --http-method GET --type MOCK --integration-http-method GET \
    --request-templates '{"application/json":"{\"statusCode\": 200}"}' >/dev/null
$AWS_CMD apigateway put-method-response --rest-api-id "${API_ID}" --resource-id "${RES_ID}" --http-method GET --status-code 200 >/dev/null
$AWS_CMD apigateway put-integration-response --rest-api-id "${API_ID}" --resource-id "${RES_ID}" --http-method GET --status-code 200 \
    --response-templates '{"application/json":"{\"message\": \"Hello from Floci API Gateway!\"}"}' >/dev/null
log_success "Mock integration configured"
section_end

section_start "5. Deploy API"
$AWS_CMD apigateway create-deployment --rest-api-id "${API_ID}" --stage-name "dev" >/dev/null
log_success "Deployed to stage: dev"
API_URL="${AWS_ENDPOINT}/restapis/${API_ID}/dev/_user_request_/items"
log_success "URL: ${API_URL}"
section_end

section_start "6. Test Endpoint"
log_step "Sending GET request..."
curl -s "${API_URL}" | sed 's/^/   /'
section_end

summary_box "API Gateway Complete" "REST API, Resources, Methods, Mock Integration, Deployment"
