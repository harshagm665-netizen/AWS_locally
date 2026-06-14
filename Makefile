.PHONY: help up down restart status logs demo test deploy clean setup

.DEFAULT_GOAL := help
COMPOSE_FILE  := docker-compose.yml
SCRIPTS_DIR   := scripts
TESTS_DIR     := tests
SHELL         := /bin/bash
C := \033[36m
G := \033[32m
Y := \033[33m
R := \033[31m
B := \033[1m
X := \033[0m

help: ## 📖 Show all commands
	@echo ""
	@echo "$(B)$(C)  ╔═══════════════════════════════════════════════════════════╗$(X)"
	@echo "$(B)$(C)  ║        Floci — AWS Services Locally                      ║$(X)"
	@echo "$(B)$(C)  ╚═══════════════════════════════════════════════════════════╝$(X)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(G)%-18s$(X) %s\n", $$1, $$2}'
	@echo ""

up: ## 🚀 Start Floci
	@echo "$(B)$(G)▸ Starting Floci...$(X)"
	@docker compose -f $(COMPOSE_FILE) up -d
	@bash utils/wait-for-floci.sh
	@echo "$(B)$(G)✓ Floci ready at http://localhost:4566$(X)"

down: ## 🛑 Stop Floci
	@docker compose -f $(COMPOSE_FILE) down

restart: down up ## 🔄 Restart Floci

status: ## 📊 Health check
	@bash $(SCRIPTS_DIR)/00-health-check.sh

logs: ## 📋 Stream logs
	@docker compose -f $(COMPOSE_FILE) logs -f --tail=100

demo: ## 🎬 Run ALL service demos
	@bash $(SCRIPTS_DIR)/run-all.sh

demo-s3: ## 📦 S3 demo
	@bash $(SCRIPTS_DIR)/01-s3-operations.sh
demo-dynamodb: ## 🗄️  DynamoDB demo
	@bash $(SCRIPTS_DIR)/02-dynamodb-operations.sh
demo-sqs: ## 📨 SQS demo
	@bash $(SCRIPTS_DIR)/03-sqs-operations.sh
demo-sns: ## 📢 SNS demo
	@bash $(SCRIPTS_DIR)/04-sns-operations.sh
demo-lambda: ## ⚡ Lambda demo
	@bash $(SCRIPTS_DIR)/05-lambda-operations.sh
demo-apigateway: ## 🌐 API Gateway demo
	@bash $(SCRIPTS_DIR)/06-apigateway-operations.sh
demo-iam: ## 🔐 IAM demo
	@bash $(SCRIPTS_DIR)/07-iam-operations.sh
demo-ec2: ## 💻 EC2 demo
	@bash $(SCRIPTS_DIR)/09-ec2-operations.sh
demo-secrets: ## 🔑 Secrets Manager demo
	@bash $(SCRIPTS_DIR)/10-secretsmanager-ops.sh
demo-stepfunctions: ## 🔀 Step Functions demo
	@bash $(SCRIPTS_DIR)/11-stepfunctions-ops.sh
demo-kinesis: ## 🌊 Kinesis demo
	@bash $(SCRIPTS_DIR)/12-kinesis-operations.sh
demo-eventbridge: ## 📅 EventBridge demo
	@bash $(SCRIPTS_DIR)/13-eventbridge-ops.sh

deploy: ## 🏗️  Deploy CloudFormation stacks
	@bash $(SCRIPTS_DIR)/08-cloudformation-deploy.sh

test: ## 🧪 Run smoke tests
	@bash $(TESTS_DIR)/smoke-test.sh

clean: ## 🧹 Remove all data
	@docker compose -f $(COMPOSE_FILE) down -v --remove-orphans 2>/dev/null || true
	@rm -rf data/
	@rm -f lambda/**/*.zip 2>/dev/null || true
	@echo "$(B)$(G)✓ Clean$(X)"

setup: ## 🔧 Initial setup
	@[ -f .env ] || cp .env.example .env
	@chmod +x scripts/*.sh utils/*.sh init-scripts/*.sh tests/*.sh 2>/dev/null || true
	@echo "$(B)$(G)✓ Setup complete. Run 'make up' to start.$(X)"
