#!/usr/bin/env bash
# ── Floci Bootstrap — Auto-init resources on startup ──
set -e
echo "═══════════════════════════════════════════════════════"
echo "  ☁️  Floci Bootstrap — Initializing Base Resources"
echo "═══════════════════════════════════════════════════════"
R="${AWS_DEFAULT_REGION:-us-east-1}"

echo "▸ Creating S3 buckets..."
aws --endpoint-url=http://localhost:4566 s3 mb s3://app-data-bucket --region "$R" 2>/dev/null || true
aws --endpoint-url=http://localhost:4566 s3 mb s3://app-logs-bucket --region "$R" 2>/dev/null || true
echo "  ✓ S3 buckets created"

echo "▸ Creating DynamoDB tables..."
aws --endpoint-url=http://localhost:4566 dynamodb create-table \
    --table-name Users --attribute-definitions AttributeName=userId,AttributeType=S \
    --key-schema AttributeName=userId,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST --region "$R" 2>/dev/null || true
echo "  ✓ DynamoDB tables created"

echo "▸ Creating SQS queues..."
aws --endpoint-url=http://localhost:4566 sqs create-queue --queue-name app-task-queue --region "$R" 2>/dev/null || true
aws --endpoint-url=http://localhost:4566 sqs create-queue --queue-name app-dlq --region "$R" 2>/dev/null || true
echo "  ✓ SQS queues created"

echo "▸ Creating SNS topics..."
aws --endpoint-url=http://localhost:4566 sns create-topic --name app-notifications --region "$R" 2>/dev/null || true
echo "  ✓ SNS topics created"

echo ""
echo "  ✅ Bootstrap complete"
echo "═══════════════════════════════════════════════════════"
