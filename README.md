# AWS Infrastructure Portfolio

Infrastructure-as-Code templates for common AWS deployment patterns, written
in both CloudFormation and Terraform. Built from hands-on coursework in
CS312 System Administration at Oregon State University and extended for
production-readiness.

Every CloudFormation template is validated on push via GitHub Actions using
`cfn-lint`. No live AWS account is required to verify the templates are
syntactically and structurally correct.

## Stacks

### CloudFormation

| Stack | Description |
|---|---|
| `cloudformation/vpc-baseline` | VPC, public/private subnets across 2 AZs, IGW, NAT Gateway, route tables |
| `cloudformation/ec2-webserver` | EC2 + Nginx, Elastic IP, parameterized SSH CIDR restriction |
| `cloudformation/lemp-stack` | Linux + Nginx + MariaDB + PHP, fully bootstrapped via UserData |
| `cloudformation/minecraft-server` | Minecraft Java Edition on EC2, persistent EBS world volume, systemd service |

All stacks except `vpc-baseline` import VPC and subnet IDs from
`vpc-baseline` via cross-stack exports. Deploy `vpc-baseline` first.

### Terraform

| Module | Description |
|---|---|
| `terraform/vpc-baseline` | Same VPC topology as the CloudFormation baseline, written in HCL |

The Terraform VPC mirrors the CloudFormation VPC exactly: same CIDR ranges,
same subnet layout, same NAT Gateway design. Demonstrates the ability to
work in both major IaC toolchains.

## Repository Layout

```
.
├── .github/workflows/cfn-lint.yml   # Validates CFN templates on every push
├── cloudformation/
│   ├── vpc-baseline/template.yaml
│   ├── ec2-webserver/template.yaml
│   ├── lemp-stack/template.yaml
│   └── minecraft-server/template.yaml
├── terraform/
│   └── vpc-baseline/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── scripts/
│   └── lemp-setup.sh                # Standalone LEMP bootstrap script
└── docs/
    └── architecture.md              # Mermaid diagrams and cost estimates
```

## Deploying

### Prerequisites

- AWS CLI configured (`aws configure`)
- An existing EC2 key pair in the target region
- CloudFormation stacks: deploy `vpc-baseline` before any others

### CloudFormation

```bash
# 1. Deploy the VPC
aws cloudformation deploy \
  --template-file cloudformation/vpc-baseline/template.yaml \
  --stack-name dev-vpc-baseline \
  --parameter-overrides EnvironmentName=dev

# 2. Deploy a stack that depends on it (example: LEMP)
aws cloudformation deploy \
  --template-file cloudformation/lemp-stack/template.yaml \
  --stack-name dev-lemp \
  --parameter-overrides \
    EnvironmentName=dev \
    KeyPairName=your-key-pair \
    DBPassword=changeme123
```

### Terraform

```bash
cd terraform/vpc-baseline
terraform init
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```

## Linting Locally

```bash
pip install cfn-lint
cfn-lint cloudformation/**/*.yaml
```

## Key Design Decisions

- **Parameterized environments**: all stacks accept an `EnvironmentName`
  parameter (`dev`/`staging`/`prod`) that prefixes every resource name,
  making it safe to deploy multiple environments in one account.
- **Cross-stack exports**: application stacks import VPC/subnet IDs from
  `vpc-baseline` rather than accepting them as raw parameters, enforcing
  the correct deployment order and preventing misconfiguration.
- **SSM for AMI resolution**: EC2 stacks use
  `AWS::SSM::Parameter::Value<AWS::EC2::Image::Id>` to always resolve the
  latest Amazon Linux 2023 AMI at deploy time rather than hard-coding AMI
  IDs that vary by region and go stale.
- **EBS persistence**: the Minecraft world volume has `DeletionPolicy:
  Retain` so world data survives stack deletion.
- **Idempotent UserData**: all bootstrap scripts use `CREATE IF NOT EXISTS`
  and conditional format checks so re-running on the same instance doesn't
  break anything.
