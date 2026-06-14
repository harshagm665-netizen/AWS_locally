#!/usr/bin/env bash
# ══ 04 — Amazon SNS Operations (Floci) ══
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/colors.sh"
print_banner "AMAZON SNS — Simple Notification Service" "📢"
check_floci

section_start "1. Create Topics"
TOPIC=$($AWS_CMD sns create-topic --name demo-notifications --query 'TopicArn' --output text)
log_success "Topic: ${TOPIC}"
section_end

section_start "2. Subscribe SQS"
SUB_Q=$($AWS_CMD sqs create-queue --queue-name sns-sub-queue --query 'QueueUrl' --output text)
SUB_ARN=$($AWS_CMD sqs get-queue-attributes --queue-url "${SUB_Q}" --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)
$AWS_CMD sns subscribe --topic-arn "${TOPIC}" --protocol sqs --notification-endpoint "${SUB_ARN}" --attributes '{"RawMessageDelivery":"true"}' --query 'SubscriptionArn' --output text
log_success "SQS subscribed to topic"
section_end

section_start "3. Filtered Subscription"
FILT_Q=$($AWS_CMD sqs create-queue --queue-name sns-critical --query 'QueueUrl' --output text)
FILT_ARN=$($AWS_CMD sqs get-queue-attributes --queue-url "${FILT_Q}" --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)
$AWS_CMD sns subscribe --topic-arn "${TOPIC}" --protocol sqs --notification-endpoint "${FILT_ARN}" \
    --attributes '{"FilterPolicy":"{\"severity\":[\"critical\"]}","RawMessageDelivery":"true"}' >/dev/null
log_success "Filtered subscription (severity=critical)"
section_end

section_start "4. List Subscriptions"
$AWS_CMD sns list-subscriptions-by-topic --topic-arn "${TOPIC}" --output json | python3 -c "
import json,sys
for s in json.load(sys.stdin).get('Subscriptions',[]):
    print(f'   • {s[\"Protocol\"]:8} → {s[\"Endpoint\"].split(\":\")[-1]}')
" 2>/dev/null
section_end

section_start "5. Publish Messages"
$AWS_CMD sns publish --topic-arn "${TOPIC}" --message '{"event":"deploy_ok"}' --message-attributes '{"severity":{"DataType":"String","StringValue":"info"}}' --query 'MessageId' --output text
log_success "Published INFO"
$AWS_CMD sns publish --topic-arn "${TOPIC}" --message '{"event":"db_down"}' --message-attributes '{"severity":{"DataType":"String","StringValue":"critical"}}' --query 'MessageId' --output text
log_success "Published CRITICAL"
sleep 1
log_detail "Main queue msgs: $($AWS_CMD sqs get-queue-attributes --queue-url "${SUB_Q}" --attribute-names ApproximateNumberOfMessages --query 'Attributes.ApproximateNumberOfMessages' --output text)"
log_detail "Critical queue:  $($AWS_CMD sqs get-queue-attributes --queue-url "${FILT_Q}" --attribute-names ApproximateNumberOfMessages --query 'Attributes.ApproximateNumberOfMessages' --output text)"
section_end

summary_box "SNS Complete" "Topics, SQS subscriptions, filter policies, publish"
