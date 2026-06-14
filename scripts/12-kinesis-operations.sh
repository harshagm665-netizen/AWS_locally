#!/usr/bin/env bash
# ══ 12 — Amazon Kinesis Operations (Floci) ══
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
print_banner "AMAZON KINESIS — Data Streams" "🌊"
check_floci
STREAM="demo-stream"

section_start "1. Create Stream"
$AWS_CMD kinesis create-stream --stream-name "${STREAM}" --shard-count 1 2>/dev/null || true
$AWS_CMD kinesis wait stream-exists --stream-name "${STREAM}" 2>/dev/null || sleep 2
log_success "Stream: ${STREAM}"
section_end

section_start "2. Put Record"
$AWS_CMD kinesis put-record --stream-name "${STREAM}" --partition-key "p1" --data "eyJrZXkiOiJ2YWx1ZSJ9" >/dev/null
log_success "Record added"
section_end

section_start "3. Read Record"
SHARD=$($AWS_CMD kinesis list-shards --stream-name "${STREAM}" --query 'Shards[0].ShardId' --output text)
ITER=$($AWS_CMD kinesis get-shard-iterator --stream-name "${STREAM}" --shard-id "${SHARD}" --shard-iterator-type TRIM_HORIZON --query 'ShardIterator' --output text)
$AWS_CMD kinesis get-records --shard-iterator "${ITER}" --limit 5 --output json | python3 -c "
import json,sys,base64
for r in json.load(sys.stdin).get('Records',[]):
    print(f'   Data: {base64.b64decode(r[\"Data\"]).decode()}')
" 2>/dev/null
section_end

summary_box "Kinesis Complete" "Create Stream, Put Record, Get Records"
