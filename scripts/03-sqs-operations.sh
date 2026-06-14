#!/usr/bin/env bash
# ══ 03 — Amazon SQS Operations (Floci) ══
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
print_banner "AMAZON SQS — Simple Queue Service" "📨"
check_floci

section_start "1. Create Queues"
DLQ_URL=$($AWS_CMD sqs create-queue --queue-name demo-dlq --query 'QueueUrl' --output text)
DLQ_ARN=$($AWS_CMD sqs get-queue-attributes --queue-url "${DLQ_URL}" --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)
log_success "DLQ: ${DLQ_URL}"

Q_URL=$($AWS_CMD sqs create-queue --queue-name demo-queue \
    --attributes '{"VisibilityTimeout":"30","RedrivePolicy":"{\"deadLetterTargetArn\":\"'"${DLQ_ARN}"'\",\"maxReceiveCount\":\"3\"}"}' \
    --query 'QueueUrl' --output text)
log_success "Queue: ${Q_URL}"

FIFO_URL=$($AWS_CMD sqs create-queue --queue-name demo-orders.fifo \
    --attributes '{"FifoQueue":"true","ContentBasedDeduplication":"true"}' \
    --query 'QueueUrl' --output text)
log_success "FIFO: ${FIFO_URL}"
section_end

section_start "2. List Queues"
$AWS_CMD sqs list-queues --output table
section_end

section_start "3. Send Messages"
for i in 1 2 3 4 5; do
    $AWS_CMD sqs send-message --queue-url "${Q_URL}" --message-body "{\"task\":\"job_${i}\",\"data\":\"payload\"}" --query 'MessageId' --output text
done
log_success "Sent 5 messages"

$AWS_CMD sqs send-message --queue-url "${FIFO_URL}" --message-body '{"order":"ORD-1"}' --message-group-id "orders" && log_success "Sent FIFO message"
section_end

section_start "4. Receive & Delete"
MSGS=$($AWS_CMD sqs receive-message --queue-url "${Q_URL}" --max-number-of-messages 3 --wait-time-seconds 2 --output json)
echo "$MSGS" | python3 -c "
import json,sys
for m in json.load(sys.stdin).get('Messages',[]):
    print(f'   • {m[\"MessageId\"][:12]}... body={m[\"Body\"][:50]}')
" 2>/dev/null

HANDLE=$(echo "$MSGS" | python3 -c "import json,sys;msgs=json.load(sys.stdin).get('Messages',[]);print(msgs[0]['ReceiptHandle'] if msgs else '')" 2>/dev/null)
[ -n "$HANDLE" ] && $AWS_CMD sqs delete-message --queue-url "${Q_URL}" --receipt-handle "${HANDLE}" && log_success "Deleted 1 message"
section_end

section_start "5. Queue Attributes"
$AWS_CMD sqs get-queue-attributes --queue-url "${Q_URL}" --attribute-names ApproximateNumberOfMessages VisibilityTimeout --output json | python3 -c "
import json,sys
for k,v in json.load(sys.stdin).get('Attributes',{}).items():print(f'   {k}: {v}')
" 2>/dev/null
section_end

section_start "6. Purge"
$AWS_CMD sqs purge-queue --queue-url "${Q_URL}" 2>/dev/null && log_success "Queue purged"
section_end

summary_box "SQS Complete" "Standard, FIFO, DLQ, send/receive/delete, purge"
