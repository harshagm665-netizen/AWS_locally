# ==============================================================================
#  AWS LocalStack — Makefile
# ==============================================================================
#  One-command operations for managing your local AWS environment.
#
#  Usage:
#    make help        Show all available targets
#    make up          Start LocalStack
#    make down        Stop LocalStack
#    make demo        Run all service demonstrations
#    make test        Run smoke tests
#    make deploy      Deploy CloudFormation stacks
# ==============================================================================

.PHONY: help up down restart status logs demo test deploy clean setup install-deps

# ── Default Target ──
.DEFAULT_GOAL := help

# ── Configuration ──
COMPOSE_FILE  := docker-compose.yml
SCRIPTS_DIR   := scripts
TESTS_DIR     := tests
CF_DIR        := cloudformation
SHELL         := /bin/bash

# ── Colors ──
CYAN    := \033[36m
GREEN   := \033[32m
YELLOW  := \033[33m
RED     := \033[31m
BOLD    := \033[1m
RESET   := \033[0m

# ==============================================================================
#  TARGETS
# ==============================================================================

help: ## 📖 Show this help message
	@echo ""
	@echo "$(BOLD)$(CYAN)  ╔══════════════════════════════════════════════════════════════╗$(RESET)"
	@echo "$(BOLD)$(CYAN)  ║          AWS LocalStack — Command Reference                 ║$(RESET)"
	@echo "$(BOLD)$(CYAN)  ╚══════════════════════════════════════════════════════════════╝$(RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-18s$(RESET) %s\n", $$1, $$2}'
	@echo ""

# ── Lifecycle ────────────────────────────────────────────────────────────────

up: ## 🚀 Start LocalStack services
	@echo "$(BOLD)$(GREEN)▸ Starting LocalStack...$(RESET)"
	@docker-compose -f $(COMPOSE_FILE) up -d
	@bash utils/wait-for-localstack.sh
	@echo "$(BOLD)$(GREEN)✓ LocalStack is ready at http://localhost:4566$(RESET)"

down: ## 🛑 Stop LocalStack services
	@echo "$(BOLD)$(YELLOW)▸ Stopping LocalStack...$(RESET)"
	@docker-compose -f $(COMPOSE_FILE) down
	@echo "$(BOLD)$(GREEN)✓ LocalStack stopped$(RESET)"

restart: down up ## 🔄 Restart LocalStack services

status: ## 📊 Check LocalStack health status
	@bash $(SCRIPTS_DIR)/00-health-check.sh

logs: ## 📋 Stream LocalStack logs
	@docker-compose -f $(COMPOSE_FILE) logs -f --tail=100

# ── Service Demonstrations ───────────────────────────────────────────────────

demo: ## 🎬 Run ALL service demonstrations
	@bash $(SCRIPTS_DIR)/run-all.sh

demo-s3: ## 📦 Run S3 operations demo
	@bash $(SCRIPTS_DIR)/01-s3-operations.sh

demo-dynamodb: ## 🗄️  Run DynamoDB operations demo
	@bash $(SCRIPTS_DIR)/02-dynamodb-operations.sh

demo-sqs: ## 📨 Run SQS operations demo
	@bash $(SCRIPTS_DIR)/03-sqs-operations.sh

demo-sns: ## 📢 Run SNS operations demo
	@bash $(SCRIPTS_DIR)/04-sns-operations.sh

demo-lambda: ## ⚡ Run Lambda operations demo
	@bash $(SCRIPTS_DIR)/05-lambda-operations.sh

demo-apigateway: ## 🌐 Run API Gateway operations demo
	@bash $(SCRIPTS_DIR)/06-apigateway-operations.sh

demo-iam: ## 🔐 Run IAM operations demo
	@bash $(SCRIPTS_DIR)/07-iam-operations.sh

demo-ec2: ## 💻 Run EC2 operations demo
	@bash $(SCRIPTS_DIR)/09-ec2-operations.sh

demo-secrets: ## 🔑 Run Secrets Manager operations demo
	@bash $(SCRIPTS_DIR)/10-secretsmanager-ops.sh

demo-stepfunctions: ## 🔀 Run Step Functions operations demo
	@bash $(SCRIPTS_DIR)/11-stepfunctions-ops.sh

demo-kinesis: ## 🌊 Run Kinesis operations demo
	@bash $(SCRIPTS_DIR)/12-kinesis-operations.sh

demo-eventbridge: ## 📅 Run EventBridge operations demo
	@bash $(SCRIPTS_DIR)/13-eventbridge-ops.sh

# ── Infrastructure as Code ───────────────────────────────────────────────────

deploy: ## 🏗️  Deploy CloudFormation stacks
	@bash $(SCRIPTS_DIR)/08-cloudformation-deploy.sh

validate: ## ✅ Validate CloudFormation templates
	@bash $(TESTS_DIR)/validate-stack.sh

# ── Testing ──────────────────────────────────────────────────────────────────

test: ## 🧪 Run smoke tests for all services
	@bash $(TESTS_DIR)/smoke-test.sh

# ── Maintenance ──────────────────────────────────────────────────────────────

clean: ## 🧹 Stop LocalStack and remove all data
	@echo "$(BOLD)$(RED)▸ Cleaning up all LocalStack data...$(RESET)"
	@docker-compose -f $(COMPOSE_FILE) down -v --remove-orphans 2>/dev/null || true
	@rm -rf volume/
	@rm -f lambda/**/*.zip 2>/dev/null || true
	@echo "$(BOLD)$(GREEN)✓ Clean complete$(RESET)"

setup: ## 🔧 Initial project setup (copy .env, install deps)
	@echo "$(BOLD)$(CYAN)▸ Setting up project...$(RESET)"
	@[ -f .env ] || cp .env.example .env
	@chmod +x scripts/*.sh utils/*.sh init-scripts/*.sh tests/*.sh 2>/dev/null || true
	@echo "$(BOLD)$(GREEN)✓ Setup complete. Run 'make up' to start.$(RESET)"

install-deps: ## 📥 Install awscli-local wrapper
	@echo "$(BOLD)$(CYAN)▸ Installing dependencies...$(RESET)"
	@pip install awscli-local
	@echo "$(BOLD)$(GREEN)✓ Dependencies installed$(RESET)"
