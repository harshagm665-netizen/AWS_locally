#!/usr/bin/env bash
# ══ Auto Fix — Troubleshoot & Resolve Common Floci Issues ══
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/colors.sh"

print_banner "AUTO FIX — Troubleshooting Toolkit" "🔧"

FIXED=0

# 1. Check Permissions
section_start "Checking file permissions"
if find "${SCRIPT_DIR}/.." -name "*.sh" -type f ! -executable | grep -q .; then
    log_step "Fixing executable permissions on shell scripts..."
    chmod +x "${SCRIPT_DIR}/.."/scripts/*.sh
    chmod +x "${SCRIPT_DIR}/.."/utils/*.sh
    chmod +x "${SCRIPT_DIR}/.."/init-scripts/*.sh
    chmod +x "${SCRIPT_DIR}/.."/tests/*.sh
    log_success "Permissions fixed."
    FIXED=$((FIXED + 1))
else
    log_success "Permissions are correct."
fi
section_end

# 2. Check Docker
section_start "Checking Docker daemon"
if ! docker info &>/dev/null; then
    log_error "Docker is not running or not accessible."
    log_detail "Fix: Please start Docker Desktop or the Docker daemon and try again."
    exit 1
else
    log_success "Docker is running."
fi
section_end

# 3. Check Port Conflicts
section_start "Checking port conflicts (4566)"
if lsof -i :4566 | grep -q LISTEN; then
    PIDS=$(lsof -t -i :4566)
    CONTAINERS=$(docker ps -q --filter "publish=4566")
    
    if [ -n "$CONTAINERS" ]; then
        log_step "Found Docker containers using port 4566. Removing them..."
        docker rm -f $CONTAINERS >/dev/null
        log_success "Conflicting containers removed."
        FIXED=$((FIXED + 1))
    else
        log_error "Port 4566 is in use by another application (PIDs: $PIDS)."
        log_detail "Fix: Kill the process using port 4566 (e.g., kill -9 $PIDS) and try again."
    fi
else
    log_success "Port 4566 is available."
fi
section_end

# 4. Check AWS CLI
section_start "Checking AWS CLI"
if ! command -v aws &>/dev/null; then
    log_error "AWS CLI is not installed."
    log_detail "Fix: Install AWS CLI. For example: pip install awscli"
else
    log_success "AWS CLI is installed."
fi
section_end

# 5. Reset Floci State
section_start "Checking Floci container state"
FLOCI_STATUS=$(docker inspect -f '{{.State.Status}}' floci-aws 2>/dev/null || echo "missing")

if [ "$FLOCI_STATUS" == "exited" ] || [ "$FLOCI_STATUS" == "dead" ] || [ "$FLOCI_STATUS" == "restarting" ]; then
    log_step "Floci is in a bad state ($FLOCI_STATUS). Hard resetting..."
    docker rm -f floci-aws >/dev/null 2>&1 || true
    rm -rf "${SCRIPT_DIR}/../data"
    log_success "Floci reset. You can now run 'make up'."
    FIXED=$((FIXED + 1))
elif [ "$FLOCI_STATUS" == "missing" ]; then
    log_success "No stale Floci container found."
else
    log_success "Floci container is running normally."
fi
section_end

echo ""
if [ $FIXED -gt 0 ]; then
    summary_box "Auto Fix Complete" "Applied ${FIXED} fixes. Try running 'make up' again."
else
    summary_box "Auto Fix Complete" "No issues found that required fixing."
fi
