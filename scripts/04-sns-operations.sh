#!/usr/bin/env bash
# ==============================================================================
#  04 — Amazon SNS Operations
# ==============================================================================
#  Demonstrates the full SNS lifecycle:
#    • Create topics (standard & FIFO)
#    • Subscriptions (SQS, email, HTTP, Lambda)
#    • Publish messages with attributes
#    • Message filtering policies
#    • Topic policies & attributes
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"

print_banner "AMAZON SNS — Simple Notification Service" "📢"
check_localstack

TOPIC_NAME="demo-notifications"
FIFO_TOPIC="demo-orders-topic.fifo"

# ══════════════════════════════════════════════════════════════════════════════
#  CREATE TOPICS
# ══════════════════════════════════════════════════════════════════════════════
section_start "1. Create Topics"

log_step "Creating standard topic: ${TOPIC_NAME}"
TOPIC_ARN=$($AWS_CMD sns create-topic \
    --name "${TOPIC_NAME}" \
    --attributes '{"DisplayName":"Demo Notifications"}' \
    --query 'TopicArn' --output text)
log_success "Topic ARN: ${TOPIC_ARN}"

log_step "Creating FIFO topic: ${FIFO_TOPIC}"
FIFO_TOPIC_ARN=$($AWS_CMD sns create-topic \
    --name "${FIFO_TOPIC}" \
    --attributes '{"FifoTopic":"true","ContentBasedDeduplication":"true"}' \
    --query 'TopicArn' --output text)
log_success "FIFO Topic ARN: ${FIFO_TOPIC_ARN}"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  LIST TOPICS
# ══════════════════════════════════════════════════════════════════════════════
section_start "2. List Topics"

$AWS_CMD sns list-topics --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
topics = data.get('Topics', [])
for t in topics:
    name = t['TopicArn'].split(':')[-1]
    print(f'   • {name}')
    print(f'     ARN: {t[\"TopicArn\"]}')
" 2>/dev/null
log_success "Topics listed"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  CREATE SQS SUBSCRIBER
# ══════════════════════════════════════════════════════════════════════════════
section_start "3. Subscribe SQS Queue to Topic"

# Create a subscriber queue
SUB_QUEUE_URL=$($AWS_CMD sqs create-queue \
    --queue-name "sns-subscriber-queue" \
    --query 'QueueUrl' --output text)
SUB_QUEUE_ARN=$($AWS_CMD sqs get-queue-attributes \
    --queue-url "${SUB_QUEUE_URL}" \
    --attribute-names QueueArn \
    --query 'Attributes.QueueArn' --output text)

log_step "Subscribing SQS queue to topic"
SUB_ARN=$($AWS_CMD sns subscribe \
    --topic-arn "${TOPIC_ARN}" \
    --protocol sqs \
    --notification-endpoint "${SUB_QUEUE_ARN}" \
    --attributes '{"RawMessageDelivery":"true"}' \
    --query 'SubscriptionArn' --output text)
log_success "Subscription ARN: ${SUB_ARN}"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  EMAIL SUBSCRIPTION (simulated)
# ══════════════════════════════════════════════════════════════════════════════
section_start "4. Email Subscription (Simulated)"

log_step "Creating email subscription"
EMAIL_SUB=$($AWS_CMD sns subscribe \
    --topic-arn "${TOPIC_ARN}" \
    --protocol email \
    --notification-endpoint "admin@example.com" \
    --query 'SubscriptionArn' --output text)
log_success "Email subscription: ${EMAIL_SUB}"
log_detail "Note: In LocalStack, email subscriptions are auto-confirmed"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  MESSAGE FILTER POLICY
# ══════════════════════════════════════════════════════════════════════════════
section_start "5. Message Filter Policy"

# Create filtered subscriber queue
FILTERED_QUEUE_URL=$($AWS_CMD sqs create-queue \
    --queue-name "sns-critical-only" \
    --query 'QueueUrl' --output text)
FILTERED_QUEUE_ARN=$($AWS_CMD sqs get-queue-attributes \
    --queue-url "${FILTERED_QUEUE_URL}" \
    --attribute-names QueueArn \
    --query 'Attributes.QueueArn' --output text)

log_step "Creating filtered subscription (severity=critical only)"
FILTERED_SUB=$($AWS_CMD sns subscribe \
    --topic-arn "${TOPIC_ARN}" \
    --protocol sqs \
    --notification-endpoint "${FILTERED_QUEUE_ARN}" \
    --attributes '{"FilterPolicy":"{\"severity\":[\"critical\"]}","RawMessageDelivery":"true"}' \
    --query 'SubscriptionArn' --output text)
log_success "Filtered subscription: ${FILTERED_SUB}"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  LIST SUBSCRIPTIONS
# ══════════════════════════════════════════════════════════════════════════════
section_start "6. List Subscriptions"

$AWS_CMD sns list-subscriptions-by-topic \
    --topic-arn "${TOPIC_ARN}" \
    --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
subs = data.get('Subscriptions', [])
print(f'   Total subscriptions: {len(subs)}')
for s in subs:
    print(f'   • Protocol: {s[\"Protocol\"]:8} Endpoint: {s[\"Endpoint\"].split(\":\")[-1]}')
" 2>/dev/null

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  PUBLISH MESSAGES
# ══════════════════════════════════════════════════════════════════════════════
section_start "7. Publish Messages"

log_step "Publishing INFO message"
$AWS_CMD sns publish \
    --topic-arn "${TOPIC_ARN}" \
    --message '{"event":"deployment","status":"success","service":"api-gateway"}' \
    --subject "Deployment Notification" \
    --message-attributes '{
        "severity":{"DataType":"String","StringValue":"info"},
        "service":{"DataType":"String","StringValue":"api-gateway"}
    }' \
    --query 'MessageId' --output text
log_success "INFO message published"

log_step "Publishing CRITICAL message"
$AWS_CMD sns publish \
    --topic-arn "${TOPIC_ARN}" \
    --message '{"event":"database_error","status":"failure","service":"rds","error":"connection_timeout"}' \
    --subject "Critical Alert" \
    --message-attributes '{
        "severity":{"DataType":"String","StringValue":"critical"},
        "service":{"DataType":"String","StringValue":"rds"}
    }' \
    --query 'MessageId' --output text
log_success "CRITICAL message published"

sleep 1

# ── Verify SQS received both messages ──
log_step "Verifying: All messages on main subscriber queue"
ALL_MSGS=$($AWS_CMD sqs get-queue-attributes \
    --queue-url "${SUB_QUEUE_URL}" \
    --attribute-names ApproximateNumberOfMessages \
    --query 'Attributes.ApproximateNumberOfMessages' --output text)
log_detail "Messages on main queue: ${ALL_MSGS}"

log_step "Verifying: Only critical on filtered queue"
CRIT_MSGS=$($AWS_CMD sqs get-queue-attributes \
    --queue-url "${FILTERED_QUEUE_URL}" \
    --attribute-names ApproximateNumberOfMessages \
    --query 'Attributes.ApproximateNumberOfMessages' --output text)
log_detail "Messages on filtered queue: ${CRIT_MSGS}"

section_end

# ══════════════════════════════════════════════════════════════════════════════
#  TOPIC ATTRIBUTES
# ══════════════════════════════════════════════════════════════════════════════
section_start "8. Topic Attributes"

$AWS_CMD sns get-topic-attributes \
    --topic-arn "${TOPIC_ARN}" \
    --output json | python3 -c "
import json, sys
attrs = json.load(sys.stdin).get('Attributes', {})
print(f'   Topic ARN:          {attrs.get(\"TopicArn\", \"N/A\")}')
print(f'   Display Name:       {attrs.get(\"DisplayName\", \"N/A\")}')
print(f'   Subscriptions:      {attrs.get(\"SubscriptionsConfirmed\", \"0\")} confirmed')
print(f'   Pending:            {attrs.get(\"SubscriptionsPending\", \"0\")}')
" 2>/dev/null

section_end

summary_box "SNS Operations Complete" \
    "Topics: standard, FIFO, attributes" \
    "Subscriptions: SQS, email, filter policies" \
    "Publishing: messages with attributes & filters"
