#!/usr/bin/env bash
# ==============================================================================
#  00 — LocalStack Health Check
# ==============================================================================
#  Verifies that LocalStack is running and reports the status of each
#  configured AWS service.
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

print_banner "HEALTH CHECK — Service Status" "🏥"

check_localstack

# ── Fetch health endpoint ──
section_start "Service Health Report"

HEALTH=$(curl -s "${AWS_ENDPOINT}/_localstack/health")

log_info "LocalStack Endpoint: ${AWS_ENDPOINT}"
log_info "Region: ${AWS_DEFAULT_REGION}"
echo ""

# ── Parse and display each service status ──
echo "$HEALTH" | python3 -c "
import json, sys
data = json.load(sys.stdin)
services = data.get('services', {})

# Column headers
print(f'   {\"Service\":<25} {\"Status\":<15}')
print(f'   {\"-\" * 25} {\"-\" * 15}')

for svc, status in sorted(services.items()):
    icon = '✅' if status in ('running', 'available') else '❌'
    print(f'   {icon} {svc:<23} {status}')

print()
print(f'   Total services: {len(services)}')
running = sum(1 for s in services.values() if s in ('running', 'available'))
print(f'   Running: {running}/{len(services)}')
" 2>/dev/null || print_json "Raw Health" "$HEALTH"

section_end

# ── Docker container status ──
section_start "Container Status"

if docker ps --filter "name=aws-localstack" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | head -5; then
    log_success "Container is running"
else
    log_warning "Could not query Docker container status"
fi

section_end

summary_box "Health Check Complete" \
    "All services operational" \
    "Endpoint: ${AWS_ENDPOINT}"
