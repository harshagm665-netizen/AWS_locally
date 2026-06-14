#!/usr/bin/env bash
# ==============================================================================
#  LocalStack Bootstrap — Auto-Initialization Script
# ==============================================================================
#  This script runs automatically when LocalStack starts.
#  It pre-provisions base resources so they're ready before any demo scripts.
#
#  Mounted to: /etc/localstack/init/ready.d/01-bootstrap.sh
# ==============================================================================

set -e

echo "═══════════════════════════════════════════════════════"
echo "  🚀 LocalStack Bootstrap — Initializing Resources"
echo "═══════════════════════════════════════════════════════"

REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# ── S3: Create base buckets ──
echo "▸ Creating S3 buckets..."
awslocal s3 mb s3://app-data-bucket --region "$REGION" 2>/dev/null || true
awslocal s3 mb s3://app-logs-bucket --region "$REGION" 2>/dev/null || true
awslocal s3 mb s3://app-assets-bucket --region "$REGION" 2>/dev/null || true
echo "  ✓ S3 buckets created"

# ── DynamoDB: Create base tables ──
echo "▸ Creating DynamoDB tables..."
awslocal dynamodb create-table \
    --table-name Users \
    --attribute-definitions \
        AttributeName=userId,AttributeType=S \
    --key-schema \
        AttributeName=userId,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION" 2>/dev/null || true

awslocal dynamodb create-table \
    --table-name Orders \
    --attribute-definitions \
        AttributeName=orderId,AttributeType=S \
        AttributeName=userId,AttributeType=S \
    --key-schema \
        AttributeName=orderId,KeyType=HASH \
        AttributeName=userId,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION" 2>/dev/null || true
echo "  ✓ DynamoDB tables created"

# ── SQS: Create base queues ──
echo "▸ Creating SQS queues..."
awslocal sqs create-queue \
    --queue-name app-task-queue \
    --region "$REGION" 2>/dev/null || true

awslocal sqs create-queue \
    --queue-name app-dlq \
    --region "$REGION" 2>/dev/null || true
echo "  ✓ SQS queues created"

# ── SNS: Create base topics ──
echo "▸ Creating SNS topics..."
awslocal sns create-topic \
    --name app-notifications \
    --region "$REGION" 2>/dev/null || true

awslocal sns create-topic \
    --name app-alerts \
    --region "$REGION" 2>/dev/null || true
echo "  ✓ SNS topics created"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  ✅ Bootstrap complete — All base resources ready"
echo "═══════════════════════════════════════════════════════"
