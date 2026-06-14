#!/usr/bin/env bash
# ==============================================================================
#  03 — Amazon SQS Operations
# ==============================================================================
#  Demonstrates the full SQS lifecycle:
#    • Create standard & FIFO queues
#    • Dead-letter queue configuration
#    • Send / Receive / Delete messages
#    • Batch send & receive
#    • Message attributes
#    • Queue attributes & purge
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

print_banner "AMAZON SQS — Simple Queue Service" "📨"
check_localstack

QUEUE_NAME="demo-task-queue"
DLQ_NAME="demo-task-dlq"
FIFO_QUEUE="demo-orders.fifo"

# ══════════════════════════════════════════════════════════════════════════════
#  CREATE QUEUES
# ══════════════════════════════════════════════════════════════════════════════
section_start "1. Create Queues"

# Create Dead Letter Queue first
log_step "Creating Dead Letter Queue: ${DLQ_NAME}"
DLQ_URL=$($AWS_CMD sqs create-queue \
    --queue-name "${DLQ_NAME}" \
    --attributes '{"MessageRetentionPeriod":"1209600"}' \
    --query 'QueueUrl' --output text)
log_success "DLQ created: ${DLQ_URL}"

# Get DLQ ARN
DLQ_ARN=$($AWS_CMD sqs get-queue-attributes \
    --queue-url "${DLQ_URL}" \
    --attribute-names QueueArn \
    --query 'Attributes.QueueArn' --output text)

# Create Standard Queue with DLQ redrive policy
log_step "Creating Standard Queue: ${QUEUE_NAME} (with DLQ redrive)"
QUEUE_URL=$($AWS_CMD sqs create-queue \
    --queue-name "${QUEUE_NAME}" \
    --attributes '{
        "VisibilityTimeout":"30",
        "MessageRetentionPeriod":"345600",
        "ReceiveMessageWaitTimeSeconds":"5",
        "RedrivePolicy":"{\"deadLetterTargetArn\":\"'"${DLQ_ARN}"'\",\"maxReceiveCount\":\"3\"}"
    }' \
    --query 'QueueUrl' --output text)
log_success "Queue created: ${QUEUE_URL}"

# Create FIFO Queue
log_step "Creating FIFO Queue: ${FIFO_QUEUE}"
FIFO_URL=$($AWS_CMD sqs create-queue \
    --queue-name "${FIFO_QUEUE}" \
    --attributes '{
        "FifoQueue":"true",
        "ContentBasedDeduplication":"true"
    }' \
    --query 'QueueUrl' --output text)
log_success "FIFO Queue created: ${FIFO_URL}"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  LIST QUEUES
# ══════════════════════════════════════════════════════════════════════════════
section_start "2. List Queues"

$AWS_CMD sqs list-queues --output table
log_success "Queues listed"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  SEND MESSAGES
# ══════════════════════════════════════════════════════════════════════════════
section_start "3. Send Messages"

log_step "Sending message with attributes"
MSG_ID=$($AWS_CMD sqs send-message \
    --queue-url "${QUEUE_URL}" \
    --message-body '{"task":"process_image","file":"photo_001.jpg","priority":"high"}' \
    --message-attributes '{
        "TaskType":{"DataType":"String","StringValue":"image_processing"},
        "Priority":{"DataType":"Number","StringValue":"1"},
        "Source":{"DataType":"String","StringValue":"upload-service"}
    }' \
    --delay-seconds 0 \
    --query 'MessageId' --output text)
log_success "Sent message: ${MSG_ID}"

log_step "Sending additional messages"
for i in {1..4}; do
    $AWS_CMD sqs send-message \
        --queue-url "${QUEUE_URL}" \
        --message-body "{\"task\":\"task_${i}\",\"payload\":\"data_${i}\"}" \
        --query 'MessageId' --output text
done
log_success "Sent 4 additional messages"

# Send to FIFO queue
log_step "Sending ordered messages to FIFO queue"
for i in {1..3}; do
    $AWS_CMD sqs send-message \
        --queue-url "${FIFO_URL}" \
        --message-body "{\"order_id\":\"ORD-${i}\",\"action\":\"process\"}" \
        --message-group-id "order-processing" \
        --query 'MessageId' --output text
done
log_success "Sent 3 FIFO messages (same group)"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  BATCH SEND
# ══════════════════════════════════════════════════════════════════════════════
section_start "4. Batch Send Messages"

log_step "Batch sending 3 messages"
$AWS_CMD sqs send-message-batch \
    --queue-url "${QUEUE_URL}" \
    --entries '[
        {"Id":"batch-1","MessageBody":"{\"batch\":\"msg1\"}","DelaySeconds":0},
        {"Id":"batch-2","MessageBody":"{\"batch\":\"msg2\"}","DelaySeconds":0},
        {"Id":"batch-3","MessageBody":"{\"batch\":\"msg3\"}","DelaySeconds":0}
    ]' --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
ok = len(data.get('Successful', []))
fail = len(data.get('Failed', []))
print(f'   Successful: {ok}  |  Failed: {fail}')
" 2>/dev/null
log_success "Batch send complete"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  RECEIVE MESSAGES
# ══════════════════════════════════════════════════════════════════════════════
section_start "5. Receive Messages"

log_step "Receiving up to 5 messages (with attributes)"
MESSAGES=$($AWS_CMD sqs receive-message \
    --queue-url "${QUEUE_URL}" \
    --max-number-of-messages 5 \
    --message-attribute-names All \
    --attribute-names All \
    --wait-time-seconds 2 \
    --output json)

echo "$MESSAGES" | python3 -c "
import json, sys
data = json.load(sys.stdin)
msgs = data.get('Messages', [])
if not msgs:
    print('   No messages available')
else:
    for m in msgs:
        body = json.loads(m['Body']) if m['Body'].startswith('{') else m['Body']
        print(f'   • ID: {m[\"MessageId\"][:12]}...')
        print(f'     Body: {json.dumps(body)}')
        attrs = m.get('MessageAttributes', {})
        if attrs:
            print(f'     Attributes: {list(attrs.keys())}')
        print()
" 2>/dev/null

# Delete first message (acknowledge)
RECEIPT_HANDLE=$(echo "$MESSAGES" | python3 -c "
import json, sys
data = json.load(sys.stdin)
msgs = data.get('Messages', [])
if msgs: print(msgs[0]['ReceiptHandle'])
" 2>/dev/null || echo "")

if [ -n "$RECEIPT_HANDLE" ]; then
    log_step "Deleting (acknowledging) first message"
    $AWS_CMD sqs delete-message \
        --queue-url "${QUEUE_URL}" \
        --receipt-handle "${RECEIPT_HANDLE}"
    log_success "Message deleted"
fi

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  QUEUE ATTRIBUTES
# ══════════════════════════════════════════════════════════════════════════════
section_start "6. Queue Attributes"

log_step "Retrieving queue attributes"
$AWS_CMD sqs get-queue-attributes \
    --queue-url "${QUEUE_URL}" \
    --attribute-names All \
    --output json | python3 -c "
import json, sys
attrs = json.load(sys.stdin).get('Attributes', {})
important = ['ApproximateNumberOfMessages', 'ApproximateNumberOfMessagesNotVisible',
             'VisibilityTimeout', 'MessageRetentionPeriod', 'RedrivePolicy']
for key in important:
    if key in attrs:
        val = attrs[key]
        if key == 'RedrivePolicy':
            val = json.loads(val)
            val = f'maxReceiveCount={val[\"maxReceiveCount\"]}'
        print(f'   {key}: {val}')
" 2>/dev/null

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  PURGE QUEUE
# ══════════════════════════════════════════════════════════════════════════════
section_start "7. Purge Queue"

log_step "Purging all messages from ${QUEUE_NAME}"
$AWS_CMD sqs purge-queue --queue-url "${QUEUE_URL}" 2>/dev/null || log_warning "Purge may have cooldown"
log_success "Queue purged"

section_end

summary_box "SQS Operations Complete" \
    "Queues: standard, FIFO, dead-letter" \
    "Messages: send, batch, receive, delete" \
    "Management: attributes, purge"
