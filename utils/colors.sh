#!/usr/bin/env bash
# ── Terminal Colors & Logging for Floci Scripts ──
readonly RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m' BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m' CYAN='\033[0;36m' WHITE='\033[1;37m' GRAY='\033[0;90m'
readonly BOLD='\033[1m' DIM='\033[2m' RESET='\033[0m'

export AWS_ENDPOINT="${AWS_ENDPOINT_URL:-http://localhost:4566}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_CMD="aws --endpoint-url=${AWS_ENDPOINT}"

log_info()    { echo -e "${CYAN}ℹ  ${RESET}$*"; }
log_success() { echo -e "${GREEN}✓  ${RESET}$*"; }
log_error()   { echo -e "${RED}✗  ${RESET}$*" >&2; }
log_warning() { echo -e "${YELLOW}⚠  ${RESET}$*"; }
log_step()    { echo -e "${BLUE}▸  ${BOLD}$*${RESET}"; }
log_detail()  { echo -e "   ${GRAY}$*${RESET}"; }
log_divider() { echo -e "${GRAY}$(printf '─%.0s' {1..70})${RESET}"; }

print_banner() {
    local name="$1" icon="${2:-☁️}"
    echo ""
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║${RESET}  ${icon}  ${BOLD}${WHITE}${name}${RESET}"
    echo -e "${BOLD}${CYAN}║${RESET}  ${DIM}Floci · Local AWS Emulator · http://localhost:4566${RESET}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

print_result() { printf "   ${GRAY}%-25s${RESET} %s\n" "$1:" "$2"; }

section_start() { echo ""; echo -e "  ${BOLD}${MAGENTA}── $1 ──${RESET}"; echo ""; }
section_end()   { echo ""; log_divider; }

summary_box() {
    local title="$1"; shift
    echo ""
    echo -e "  ${BOLD}${GREEN}┌─────────────────────────────────────────────┐${RESET}"
    echo -e "  ${BOLD}${GREEN}│  ✓ ${title}${RESET}"
    for line in "$@"; do echo -e "  ${GREEN}│${RESET}  ${line}"; done
    echo -e "  ${BOLD}${GREEN}└─────────────────────────────────────────────┘${RESET}"
    echo ""
}

check_floci() {
    if ! curl -s "${AWS_ENDPOINT}/_floci/health" &>/dev/null && \
       ! curl -s "${AWS_ENDPOINT}/_localstack/health" &>/dev/null; then
        log_error "Floci is not running at ${AWS_ENDPOINT}"
        log_info  "Start it with: docker compose up -d"
        exit 1
    fi
}
