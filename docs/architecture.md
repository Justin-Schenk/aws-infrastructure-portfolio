# Architecture Overview

## VPC Baseline

The VPC baseline template provisions the network foundation all other stacks
deploy into. Two AZs, public and private subnets in each, a single NAT
Gateway in the first public subnet for private subnet egress.

```mermaid
graph TB
    subgraph VPC["VPC (10.0.0.0/16)"]
        subgraph AZ1["Availability Zone 1"]
            PUB1["Public Subnet\n10.0.1.0/24"]
            PRIV1["Private Subnet\n10.0.11.0/24"]
        end
        subgraph AZ2["Availability Zone 2"]
            PUB2["Public Subnet\n10.0.2.0/24"]
            PRIV2["Private Subnet\n10.0.12.0/24"]
        end
        NAT["NAT Gateway\n(in Public Subnet 1)"]
        PUB1 --> NAT
        NAT --> PRIV1
        NAT --> PRIV2
    end
    IGW["Internet Gateway"]
    INTERNET["Internet"]
    IGW --> PUB1
    IGW --> PUB2
    INTERNET <--> IGW
```

## Stack Dependency Map

```mermaid
graph LR
    VPC["vpc-baseline\n(CloudFormation or Terraform)"]
    EC2["ec2-webserver"]
    LEMP["lemp-stack"]
    MC["minecraft-server"]
    VPC --> EC2
    VPC --> LEMP
    VPC --> MC
```

The `ec2-webserver`, `lemp-stack`, and `minecraft-server` stacks all
import VPC and subnet IDs from the `vpc-baseline` stack via CloudFormation
cross-stack exports (`!ImportValue`). Deploy `vpc-baseline` first in any
environment before deploying the others.

## Cost Estimate (us-west-2, on-demand, approximate)

| Resource | Type | $/hr | Notes |
|---|---|---|---|
| NAT Gateway | - | $0.045 | Plus $0.045/GB data processed |
| EC2 webserver | t3.micro | $0.0104 | Free tier eligible (750 hrs/mo first year) |
| EC2 LEMP | t3.micro | $0.0104 | Free tier eligible |
| EC2 Minecraft | t3.medium | $0.0416 | Needs 2+ GB RAM |
| EBS (world data) | gp3, 10 GB | ~$0.008/day | $0.08/GB/month |

For a dev/portfolio environment running a few hours of testing: under $1
total. The NAT Gateway is the only resource that costs money while idle
(~$1.08/day). Tear the VPC stack down between sessions if cost is a concern.
