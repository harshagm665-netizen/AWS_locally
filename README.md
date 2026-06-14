<div align="center">

# ☁️ AWS Services Locally with Floci

**The definitive guide to running AWS services on your local machine — zero cost, zero AWS account.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-Required-2496ED?logo=docker)](https://docker.com)
[![Floci](https://img.shields.io/badge/Floci-Latest-5C2D91)](https://floci.io)
[![AWS Services](https://img.shields.io/badge/AWS_Services-13+-FF9900?logo=amazonaws)](https://floci.io/floci/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

*Production-grade scripts demonstrating 13+ AWS services with Floci — copy, paste, and run.*

---

[Quick Start](#-quick-start) •
[Services](#-services-covered) •
[Architecture](#-architecture) •
[Usage](#-usage) •
[Why Floci?](#-why-floci) •
[Troubleshooting](#-troubleshooting)

</div>

---

## 🎯 What Is This?

A **complete, self-contained** project that lets you run and experiment with **all major AWS services** locally using [Floci](https://floci.io) — a fast, free, open-source AWS emulator. Each service has a dedicated script with full CRUD operations, professional output, and inline documentation.

**Perfect for:**
- 🎓 Learning AWS services without an AWS account
- 🔧 Local development and testing
- 🏗️ Prototyping infrastructure before deploying to production
- 📋 Interview prep and hands-on demonstrations
- 🧪 CI/CD pipeline testing

---

## 🚀 Why Floci?

| Feature | Floci | LocalStack (Free) |
|---------|-------|-------------------|
| **Startup time** | ~24ms | ~5-10s |
| **Memory (idle)** | ~13 MiB | ~300+ MiB |
| **License** | MIT — forever free | Community Edition (limited) |
| **Feature gates** | None | Many Pro-only features |
| **Auth tokens** | Not required | Required for some features |
| **AWS services** | 50+ | ~30 (free tier) |
| **Multi-cloud** | AWS + Azure + GCP | AWS only |

---

## ⚡ Quick Start

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Docker | 20.10+ | [docker.com](https://docs.docker.com/get-docker/) |
| Docker Compose | 2.0+ | Included with Docker Desktop |
| AWS CLI | 2.x | `pip install awscli` |

### Option A: Docker Compose (Recommended)

```bash
git clone https://github.com/harshagm665-netizen/AWS_locally.git
cd AWS_locally
make setup
make up
```

### Option B: Floci CLI

```bash
# Install Floci CLI
# macOS/Linux:
curl -fsSL https://floci.io/install.sh | sh

# Windows (PowerShell):
irm https://floci.io/install.ps1 | iex

# Start Floci
floci start

# Export environment variables
eval $(floci env)    # Linux/macOS
```

### Run Demos

```bash
# Run everything
make demo

# Or run individual services
make demo-s3
make demo-dynamodb
make demo-lambda
```

### Run Smoke Tests

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
│                    Floci (localhost:4566)                     │
│            Fast, free, open-source AWS emulator               │
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

> 📖 See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed diagrams.

---

## 📁 Project Structure

```
aws-locally-floci/
├── docker-compose.yml              # Floci orchestration
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
├── init-scripts/                   # Auto-run on Floci startup
│   └── 01-bootstrap.sh           # Pre-provision base resources
│
├── tests/                         # Validation
│   ├── smoke-test.sh             # All-service smoke test
│   └── validate-stack.sh         # CloudFormation validation
│
├── utils/                         # Shared utilities
│   ├── colors.sh                 # Terminal formatting & logging
│   └── wait-for-floci.sh         # Health check with retry
│
└── docs/                          # Documentation
    └── ARCHITECTURE.md            # Architecture diagrams
```

---

## 🔧 Usage

### Makefile Commands

| Command | Description |
|---------|-------------|
| `make up` | 🚀 Start Floci |
| `make down` | 🛑 Stop Floci |
| `make restart` | 🔄 Restart Floci |
| `make status` | 📊 Health check dashboard |
| `make logs` | 📋 Stream Floci logs |
| `make demo` | 🎬 Run ALL service demos |
| `make demo-s3` | 📦 Run S3 demo only |
| `make demo-lambda` | ⚡ Run Lambda demo only |
| `make deploy` | 🏗️ Deploy CloudFormation stacks |
| `make test` | 🧪 Run smoke tests |
| `make clean` | 🧹 Remove all data & containers |
| `make setup` | 🔧 Initial project setup |

### Running Individual Scripts

```bash
bash scripts/01-s3-operations.sh
```

### Endpoints & Credentials

All services accessible at:

```
http://localhost:4566
```

Use the standard AWS CLI with `--endpoint-url`:

```bash
aws --endpoint-url=http://localhost:4566 s3 ls
```

Or set environment variables:
```bash
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Then use AWS CLI normally
aws s3 ls
```

---

## 🐛 Troubleshooting

### Floci won't start
```bash
docker info                      # Check Docker is running
docker-compose logs floci        # View logs
lsof -i :4566                   # Check port conflicts
```

### Lambda functions fail
```bash
# Ensure Docker socket is mounted (check docker-compose.yml)
make demo-lambda
```

### Permission denied on scripts
```bash
chmod +x scripts/*.sh utils/*.sh tests/*.sh init-scripts/*.sh
```

### Reset everything
```bash
make clean && make up
```

---

## 📚 Resources

- [Floci Official Docs](https://floci.io/floci/)
- [Floci GitHub](https://github.com/floci-io)
- [Floci AWS Services List](https://floci.io/floci/services/)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/latest/reference/)

---

## 📝 License

MIT License — see [LICENSE](LICENSE) for details.

---

<div align="center">

**Built with ☁️ Floci — the fast, free, open-source AWS emulator**

*Star ⭐ this repo if you find it useful!*

</div>
