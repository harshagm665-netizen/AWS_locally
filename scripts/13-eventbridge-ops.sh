#!/usr/bin/env bash
# ══ 13 — Amazon EventBridge Operations (Floci) ══
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
print_banner "AMAZON EVENTBRIDGE — Event Bus" "📅"
check_floci

BUS="demo-bus"
section_start "1. Create Bus & Rule"
$AWS_CMD events create-event-bus --name "${BUS}" >/dev/null || true
log_success "Bus: ${BUS}"
$AWS_CMD events put-rule --name "demo-rule" --event-bus-name "${BUS}" --event-pattern '{"source":["demo.app"]}' >/dev/null
log_success "Rule: demo-rule"
section_end

section_start "2. Put Events"
$AWS_CMD events put-events --entries '[{"EventBusName":"'${BUS}'","Source":"demo.app","DetailType":"test","Detail":"{}"}]' >/dev/null
log_success "Event published"
section_end

summary_box "EventBridge Complete" "Create Bus, Rule, Put Events"
