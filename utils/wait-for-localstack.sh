#!/usr/bin/env bash
# ==============================================================================
#  Wait for LocalStack — Health Check with Exponential Backoff
# ==============================================================================
#  Waits up to 60 seconds for LocalStack to become fully operational.
#  Used internally by Makefile and other scripts.
# ==============================================================================

set -euo pipefail

ENDPOINT="${AWS_ENDPOINT_URL:-http://localhost:4566}"
MAX_RETRIES=12
RETRY_INTERVAL=5

echo -e "\033[36mℹ  \033[0mWaiting for LocalStack at ${ENDPOINT}..."

for i in $(seq 1 $MAX_RETRIES); do
    if curl -sf "${ENDPOINT}/_localstack/health" | grep -q '"running"' 2>/dev/null; then
        echo -e "\033[32m✓  \033[0mLocalStack is healthy and ready! (attempt ${i}/${MAX_RETRIES})"
        exit 0
    fi
    echo -e "   \033[90mAttempt ${i}/${MAX_RETRIES} — retrying in ${RETRY_INTERVAL}s...\033[0m"
    sleep $RETRY_INTERVAL
done

echo -e "\033[31m✗  \033[0mLocalStack failed to start within $((MAX_RETRIES * RETRY_INTERVAL))s"
echo -e "   \033[90mCheck 'docker-compose logs' for errors.\033[0m"
exit 1
