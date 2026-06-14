<div align="center">

# ☁️ AWS Services Locally with LocalStack

**The definitive reference for running AWS services on your local machine.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-Required-2496ED?logo=docker)](https://docker.com)
[![LocalStack](https://img.shields.io/badge/LocalStack-4.0-5C2D91)](https://localstack.cloud)
[![AWS Services](https://img.shields.io/badge/AWS_Services-13+-FF9900?logo=amazonaws)](https://aws.amazon.com)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

*Production-grade scripts demonstrating 13+ AWS services — copy, paste, and run. Zero AWS costs.*

---

[Quick Start](#-quick-start) •
[Services](#-services-covered) •
[Architecture](#-architecture) •
[Usage](#-usage) •
[Troubleshooting](#-troubleshooting)

</div>

---

## 🎯 What Is This?

A **complete, self-contained** project that lets you run and experiment with **all major AWS services** locally using [LocalStack](https://localstack.cloud). Each service has a dedicated script with full CRUD operations, professional output formatting, and inline documentation.

**Perfect for:**
- 🎓 Learning AWS services without an AWS account
- 🔧 Local development and testing
- 🏗️ Prototyping infrastructure before deploying to production
- 📋 Interview prep and hands-on demonstrations
- 🧪 CI/CD pipeline testing

---

## ⚡ Quick Start

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Docker | 20.10+ | [docker.com](https://docs.docker.com/get-docker/) |
| Docker Compose | 2.0+ | Included with Docker Desktop |
| AWS CLI | 2.x | `pip install awscli` |
| awslocal | Latest | `pip install awscli-local` |

### 1. Clone & Setup

```bash
git clone https://github.com/YOUR_USERNAME/aws-locally.git
cd aws-locally
make setup
```

### 2. Start LocalStack

```bash
make up
```

### 3. Run Demos

```bash
# Run everything
make demo

# Or run individual services
make demo-s3
make demo-dynamodb
make demo-lambda
```

### 4. Run Smoke Tests

```bash
make test
```

---

## 📦 Services Covered

| # | Service | Script | Key Operations |
|---|---------|--------|----------------|
| 1 | **S3** | `01-s3-operations.sh` | Buckets, upload/download, versioning, presigned URLs, policies |
| 2 | **DynamoDB** | `02-dynamodb-operations.sh` | Tables, CRUD, GSI queries, scans, batch ops |
| 3 | **SQS** | `03-sqs-operations.sh` | Standard/FIFO queues, DLQ, send/receive, batch |
| 4 | **SNS** | `04-sns-operations.sh` | Topics, subscriptions, filter policies, publish |
| 5 | **Lambda** | `05-lambda-operations.sh` | Deploy, invoke sync/async, env vars, versioning |
| 6 | **API Gateway** | `06-apigateway-operations.sh` | REST API, resources, Lambda proxy, deploy & test |
| 7 | **IAM** | `07-iam-operations.sh` | Users, groups, roles, custom policies, access keys |
| 8 | **CloudFormation** | `08-cloudformation-deploy.sh` | Validate, create stacks, resources, events |
| 9 | **EC2** | `09-ec2-operations.sh` | Key pairs, security groups, instances, lifecycle |
| 10 | **Secrets Manager** | `10-secretsmanager-ops.sh` | Create/retrieve/rotate secrets, delete & restore |
| 11 | **Step Functions** | `11-stepfunctions-ops.sh` | State machines, execution, history |
| 12 | **Kinesis** | `12-kinesis-operations.sh` | Streams, produce/consume, batch put |
| 13 | **EventBridge** | `13-eventbridge-ops.sh` | Event buses, rules, pattern matching, targets |

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                  AWS LocalStack (localhost:4566)              │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│   Client ──▶ API Gateway ──▶ Lambda ──▶ DynamoDB            │
│                                  │                           │
│                          ┌───────┼───────┐                   │
│                          ▼       ▼       ▼                   │
│                         S3     SQS     SNS                   │
│                                  │       │                   │
│                                  ▼       ▼                   │
│                          Event Processor Lambda              │
│                                                              │
│   Supporting: IAM │ Secrets │ Kinesis │ EventBridge │ EC2    │
│                   │ Manager │ Streams │  Event Bus  │        │
│                   │ Step Functions │ CloudFormation │         │
└──────────────────────────────────────────────────────────────┘
```

> 📖 See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed diagrams and data flow.

---

## 📁 Project Structure

```
aws-locally/
├── docker-compose.yml              # LocalStack orchestration
├── Makefile                        # One-command operations
├── .env.example                    # Environment template
│
├── scripts/                        # 14 service demonstration scripts
│   ├── 00-health-check.sh         # Service health dashboard
│   ├── 01-s3-operations.sh        # S3 full lifecycle
│   ├── ...                        # (02-13 for each service)
│   └── run-all.sh                 # Execute all scripts
│
├── lambda/                         # Lambda function source code
│   ├── hello-world/               # Basic invocation demo
│   ├── api-processor/             # REST API handler (CRUD)
│   └── event-processor/           # SQS/SNS event handler
│
├── cloudformation/                 # Infrastructure as Code
│   ├── full-stack.yaml            # S3 + DDB + SQS + SNS + IAM
│   └── networking.yaml            # VPC + Subnets + Security Groups
│
├── init-scripts/                   # Auto-run on LocalStack startup
│   └── 01-bootstrap.sh           # Pre-provision base resources
│
├── tests/                         # Validation
│   ├── smoke-test.sh             # All-service smoke test
│   └── validate-stack.sh         # CloudFormation validation
│
├── utils/                         # Shared utilities
│   ├── colors.sh                 # Terminal formatting & logging
│   └── wait-for-localstack.sh    # Health check with retry
│
└── docs/                          # Documentation
    └── ARCHITECTURE.md            # Architecture diagrams
```

---

## 🔧 Usage

### Makefile Commands

| Command | Description |
|---------|-------------|
| `make up` | 🚀 Start LocalStack |
| `make down` | 🛑 Stop LocalStack |
| `make restart` | 🔄 Restart LocalStack |
| `make status` | 📊 Health check dashboard |
| `make logs` | 📋 Stream LocalStack logs |
| `make demo` | 🎬 Run ALL service demos |
| `make demo-s3` | 📦 Run S3 demo only |
| `make demo-lambda` | ⚡ Run Lambda demo only |
| `make deploy` | 🏗️ Deploy CloudFormation stacks |
| `make validate` | ✅ Validate CF templates |
| `make test` | 🧪 Run smoke tests |
| `make clean` | 🧹 Remove all data & containers |
| `make setup` | 🔧 Initial project setup |
| `make install-deps` | 📥 Install awscli-local |

### Running Individual Scripts

```bash
# Direct execution
bash scripts/01-s3-operations.sh

# Or use make targets
make demo-dynamodb
make demo-sqs
make demo-lambda
```

### CloudFormation Deployment

```bash
# Validate templates
make validate

# Deploy full stack
make deploy

# Or deploy manually
awslocal cloudformation create-stack \
    --stack-name my-stack \
    --template-body file://cloudformation/full-stack.yaml
```

---

## 🌐 Endpoints

All services are accessible via a single endpoint:

```
http://localhost:4566
```

Use `awslocal` (recommended) or the standard AWS CLI with `--endpoint-url`:

```bash
# Using awslocal (auto-routes to LocalStack)
awslocal s3 ls

# Using standard AWS CLI
aws --endpoint-url=http://localhost:4566 s3 ls
```

**Credentials** (any dummy values work):
```
AWS_ACCESS_KEY_ID=localstack
AWS_SECRET_ACCESS_KEY=localstack
AWS_DEFAULT_REGION=us-east-1
```

---

## 🐛 Troubleshooting

### LocalStack won't start
```bash
# Check Docker is running
docker info

# Check port conflicts
lsof -i :4566

# View container logs
docker-compose logs localstack
```

### "command not found: awslocal"
```bash
pip install awscli-local
```

### Lambda functions fail
```bash
# Ensure Docker socket is mounted (check docker-compose.yml)
# Re-run the Lambda script to recreate functions
make demo-lambda
```

### Permission denied on scripts
```bash
chmod +x scripts/*.sh utils/*.sh tests/*.sh init-scripts/*.sh
```

### Reset everything
```bash
make clean
make up
```

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/new-service`)
3. Add your service script in `scripts/`
4. Update the smoke test in `tests/smoke-test.sh`
5. Submit a Pull Request

---

## 📝 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Built with ❤️ for the AWS developer community**

*Star ⭐ this repo if you find it useful!*

</div>
