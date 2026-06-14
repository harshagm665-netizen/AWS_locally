#!/usr/bin/env bash
# ==============================================================================
#  12 — Amazon Kinesis Operations
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

print_banner "AMAZON KINESIS — Data Streams" "🌊"
check_localstack

STREAM_NAME="demo-event-stream"

# ── Create Stream ──
section_start "1. Create Kinesis Stream"
log_step "Creating stream: ${STREAM_NAME} (2 shards)"
$AWS_CMD kinesis create-stream \
    --stream-name "${STREAM_NAME}" \
    --shard-count 2 2>/dev/null || log_detail "Stream may already exist"

sleep 2

$AWS_CMD kinesis wait stream-exists --stream-name "${STREAM_NAME}" 2>/dev/null || sleep 2
log_success "Stream created: ${STREAM_NAME}"
section_end

# ── Describe Stream ──
section_start "2. Describe Stream"
$AWS_CMD kinesis describe-stream-summary \
    --stream-name "${STREAM_NAME}" \
    --output json | python3 -c "
import json, sys
d = json.load(sys.stdin).get('StreamDescriptionSummary', {})
print(f'   Stream Name:   {d.get(\"StreamName\", \"N/A\")}')
print(f'   Status:        {d.get(\"StreamStatus\", \"N/A\")}')
print(f'   Shards:        {d.get(\"OpenShardCount\", \"N/A\")}')
print(f'   Retention:     {d.get(\"RetentionPeriodHours\", 24)} hours')
print(f'   ARN:           {d.get(\"StreamARN\", \"N/A\")}')
" 2>/dev/null
section_end

# ── Put Records ──
section_start "3. Put Records"
EVENTS=(
    '{"event":"user_signup","userId":"U001","email":"alice@example.com","timestamp":"2025-01-15T10:00:00Z"}'
    '{"event":"page_view","userId":"U001","page":"/dashboard","timestamp":"2025-01-15T10:01:00Z"}'
    '{"event":"purchase","userId":"U002","amount":99.99,"product":"widget","timestamp":"2025-01-15T10:02:00Z"}'
    '{"event":"user_signup","userId":"U003","email":"charlie@example.com","timestamp":"2025-01-15T10:03:00Z"}'
    '{"event":"api_call","endpoint":"/v1/items","method":"GET","latency_ms":42,"timestamp":"2025-01-15T10:04:00Z"}'
)

for i in "${!EVENTS[@]}"; do
    EVENT="${EVENTS[$i]}"
    PARTITION_KEY=$(echo "$EVENT" | python3 -c "import json,sys;print(json.load(sys.stdin).get('userId','default'))" 2>/dev/null || echo "key-$i")

    SEQ=$($AWS_CMD kinesis put-record \
        --stream-name "${STREAM_NAME}" \
        --data "$EVENT" \
        --partition-key "${PARTITION_KEY}" \
        --cli-binary-format raw-in-base64-out \
        --query 'SequenceNumber' --output text 2>/dev/null)
    log_success "Put record $((i+1))/5 → shard partition: ${PARTITION_KEY} (seq: ${SEQ:0:12}...)"
done
section_end

# ── Get Records ──
section_start "4. Get Records (Consumer)"
log_step "Getting shard iterator"
SHARD_ID=$($AWS_CMD kinesis list-shards \
    --stream-name "${STREAM_NAME}" \
    --query 'Shards[0].ShardId' --output text 2>/dev/null)

SHARD_ITERATOR=$($AWS_CMD kinesis get-shard-iterator \
    --stream-name "${STREAM_NAME}" \
    --shard-id "${SHARD_ID}" \
    --shard-iterator-type TRIM_HORIZON \
    --query 'ShardIterator' --output text 2>/dev/null)

log_step "Reading records from shard: ${SHARD_ID}"
$AWS_CMD kinesis get-records \
    --shard-iterator "${SHARD_ITERATOR}" \
    --limit 10 \
    --output json 2>/dev/null | python3 -c "
import json, sys, base64
data = json.load(sys.stdin)
records = data.get('Records', [])
print(f'   Retrieved {len(records)} records:')
for r in records:
    payload = base64.b64decode(r['Data']).decode('utf-8')
    event = json.loads(payload)
    ts = r.get('ApproximateArrivalTimestamp', '?')
    print(f'     • [{event.get(\"event\",\"?\")}] {json.dumps(event)[:70]}...')
print(f'   Behind latest: {data.get(\"MillisBehindLatest\", \"?\")} ms')
" 2>/dev/null
section_end

# ── Batch Put ──
section_start "5. Batch Put Records"
log_step "Putting batch of 3 records"
$AWS_CMD kinesis put-records \
    --stream-name "${STREAM_NAME}" \
    --records \
        "Data=$(echo -n '{"event":"batch_1","data":"hello"}' | base64),PartitionKey=batch" \
        "Data=$(echo -n '{"event":"batch_2","data":"world"}' | base64),PartitionKey=batch" \
        "Data=$(echo -n '{"event":"batch_3","data":"test"}' | base64),PartitionKey=batch" \
    --output json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'   Failed: {d.get(\"FailedRecordCount\", 0)}')
print(f'   Records: {len(d.get(\"Records\", []))}')
" 2>/dev/null
log_success "Batch put complete"
section_end

# ── List Streams ──
section_start "6. List All Streams"
$AWS_CMD kinesis list-streams --output json | python3 -c "
import json, sys
streams = json.load(sys.stdin).get('StreamNames', [])
for s in streams:
    print(f'   • {s}')
print(f'   Total: {len(streams)}')
" 2>/dev/null
section_end

summary_box "Kinesis Operations Complete" \
    "Stream: ${STREAM_NAME} (2 shards)" \
    "Producer: put-record, put-records (batch)" \
    "Consumer: shard iterator, get-records"
