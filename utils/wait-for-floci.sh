#!/usr/bin/env bash
# ── Wait for Floci to become healthy ──
set -euo pipefail
ENDPOINT="${AWS_ENDPOINT_URL:-http://localhost:4566}"
MAX=12; WAIT=3
echo -e "\033[36mℹ  \033[0mWaiting for Floci at ${ENDPOINT}..."
for i in $(seq 1 $MAX); do
    if curl -sf "${ENDPOINT}/_floci/health" &>/dev/null || \
       curl -sf "${ENDPOINT}/_localstack/health" &>/dev/null; then
        echo -e "\033[32m✓  \033[0mFloci is ready! (attempt ${i}/${MAX})"
        exit 0
    fi
    echo -e "   \033[90mAttempt ${i}/${MAX} — retrying in ${WAIT}s...\033[0m"
    sleep $WAIT
done
echo -e "\033[31m✗  \033[0mFloci failed to start within $((MAX * WAIT))s"
exit 1
