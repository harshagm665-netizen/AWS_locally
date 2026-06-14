#!/usr/bin/env bash
# ==============================================================================
#  Terminal Color Codes & Logging Utilities
# ==============================================================================
#  Source this file in any script for consistent, professional output:
#    source "$(dirname "$0")/../utils/colors.sh"
# ==============================================================================

# ── ANSI Color Codes ──
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;90m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly UNDERLINE='\033[4m'
readonly RESET='\033[0m'

# ── Status Icons ──
readonly ICON_SUCCESS="✓"
readonly ICON_ERROR="✗"
readonly ICON_WARNING="⚠"
readonly ICON_INFO="ℹ"
readonly ICON_ARROW="▸"
readonly ICON_ROCKET="🚀"
readonly ICON_CHECK="✅"
readonly ICON_CROSS="❌"

# ── AWS Endpoint ──
export AWS_ENDPOINT="${AWS_ENDPOINT_URL:-http://localhost:4566}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-localstack}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-localstack}"

# ── AWS CLI Command (auto-detect awslocal vs aws --endpoint-url) ──
if command -v awslocal &>/dev/null; then
    AWS_CMD="awslocal"
else
    AWS_CMD="aws --endpoint-url=${AWS_ENDPOINT}"
fi
export AWS_CMD

# ==============================================================================
#  Logging Functions
# ==============================================================================

log_info() {
    echo -e "${CYAN}${ICON_INFO}  ${RESET}$*"
}

log_success() {
    echo -e "${GREEN}${ICON_SUCCESS}  ${RESET}$*"
}

log_error() {
    echo -e "${RED}${ICON_ERROR}  ${RESET}$*" >&2
}

log_warning() {
    echo -e "${YELLOW}${ICON_WARNING}  ${RESET}$*"
}

log_step() {
    echo -e "${BLUE}${ICON_ARROW}  ${BOLD}$*${RESET}"
}

log_detail() {
    echo -e "   ${GRAY}$*${RESET}"
}

log_divider() {
    echo -e "${GRAY}$(printf '─%.0s' {1..70})${RESET}"
}

# ==============================================================================
#  Banner / Header
# ==============================================================================

print_banner() {
    local service_name="$1"
    local service_icon="${2:-📦}"
    echo ""
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║${RESET}  ${service_icon}  ${BOLD}${WHITE}${service_name}${RESET}"
    echo -e "${BOLD}${CYAN}║${RESET}  ${DIM}AWS LocalStack · Local Development Environment${RESET}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

# ==============================================================================
#  Result Formatting
# ==============================================================================

print_result() {
    local label="$1"
    local value="$2"
    printf "   ${GRAY}%-25s${RESET} %s\n" "$label:" "$value"
}

print_json() {
    local label="$1"
    local json="$2"
    echo -e "   ${GRAY}${label}:${RESET}"
    echo "$json" | python3 -m json.tool 2>/dev/null | sed 's/^/      /' || echo "      $json"
}

# ==============================================================================
#  Error Handling
# ==============================================================================

check_localstack() {
    if ! curl -s "${AWS_ENDPOINT}/_localstack/health" &>/dev/null; then
        log_error "LocalStack is not running at ${AWS_ENDPOINT}"
        log_info  "Start it with: docker-compose up -d"
        exit 1
    fi
}

handle_error() {
    local exit_code=$?
    local command="$1"
    if [ $exit_code -ne 0 ]; then
        log_error "Command failed: ${command} (exit code: ${exit_code})"
        return 1
    fi
    return 0
}

# ==============================================================================
#  Section Separators
# ==============================================================================

section_start() {
    local title="$1"
    echo ""
    echo -e "  ${BOLD}${MAGENTA}── ${title} ──${RESET}"
    echo ""
}

section_end() {
    echo ""
    log_divider
}

summary_box() {
    local title="$1"
    shift
    echo ""
    echo -e "  ${BOLD}${GREEN}┌─────────────────────────────────────────────┐${RESET}"
    echo -e "  ${BOLD}${GREEN}│  ${ICON_SUCCESS} ${title}${RESET}"
    for line in "$@"; do
        echo -e "  ${GREEN}│${RESET}  ${line}"
    done
    echo -e "  ${BOLD}${GREEN}└─────────────────────────────────────────────┘${RESET}"
    echo ""
}
