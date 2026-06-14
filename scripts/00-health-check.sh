#!/usr/bin/env bash
# ══ 00 — Floci Health Check ══
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
print_banner "HEALTH CHECK — Floci Service Status" "🏥"
check_floci

section_start "Service Health"
log_info "Endpoint: ${AWS_ENDPOINT}"
log_info "Region:   ${AWS_DEFAULT_REGION}"
echo ""

# Try Floci-native endpoint first, fall back to LocalStack-compat
HEALTH=$(curl -s "${AWS_ENDPOINT}/_floci/health" 2>/dev/null || \
         curl -s "${AWS_ENDPOINT}/_localstack/health" 2>/dev/null || echo '{}')

echo "$HEALTH" | python3 -c "
import json, sys
data = json.load(sys.stdin)
services = data.get('services', {})
print(f'   {\"Service\":<25} {\"Status\":<15}')
print(f'   {\"-\"*25} {\"-\"*15}')
for svc, status in sorted(services.items()):
    icon = '✅' if status in ('running','available') else '❌'
    print(f'   {icon} {svc:<23} {status}')
print()
running = sum(1 for s in services.values() if s in ('running','available'))
print(f'   Running: {running}/{len(services)}')
" 2>/dev/null || echo "   Raw: $HEALTH"

section_end
docker ps --filter "name=floci" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | head -5
summary_box "Health Check Complete" "Floci is operational"
