````markdown
# n8n-deploy-aws

- AWS infrastructure provisioned with Terraform.
- Secure defaults: IMDSv2 enforced, SSH restricted to an admin IP, encrypted EBS root volume.
- Ansible host configuration for Docker, nginx, certbot, n8n and PostgreSQL is in progress.

n8n-deploy-aws is a production-oriented proof of concept for deploying a self-hosted [n8n](https://n8n.io) stack on AWS EC2.

The current version provisions the AWS infrastructure: VPC, public subnet, Internet Gateway, route table, Security Group, Ubuntu 24.04 EC2 instance, Elastic IP, SSH key pair, and Terraform outputs for SSH and Ansible inventory generation.

The target v1 stack will configure nginx as a host-level reverse proxy, n8n and PostgreSQL in Docker Compose, and a Let's Encrypt TLS certificate using Ansible.

## Prerequisites

- Terraform >= 1.14
- Ansible >= 2.15
- AWS CLI >= 2 configured (`aws configure`)
- An SSH key pair dedicated to this project
- A domain or subdomain pointing to the EC2 Elastic IP will be required later for Let's Encrypt TLS certificates

**Generate a dedicated SSH key pair:**
```bash
ssh-keygen -t ed25519 -f ~/.ssh/n8n-deploy-aws_key -N "" -C "n8n-deploy-aws"
````

**Detect your public IP for SSH access:**

```bash
curl -s https://ifconfig.me
```

**Configure your variables — copy the example and fill in the values:**

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Required values in `terraform.tfvars`:

| Variable         | Description                                             |
| ---------------- | ------------------------------------------------------- |
| `admin_ip`       | Your public IP with /32 suffix (e.g. `203.0.113.10/32`) |
| `ssh_public_key` | Content of `~/.ssh/n8n-deploy-aws_key.pub`              |

---

## Provision the AWS infrastructure

```bash
terraform -chdir=terraform init
terraform -chdir=terraform apply -auto-approve
```

After apply, retrieve the outputs:

```bash
# EC2 public IP
terraform -chdir=terraform output ec2_public_ip

# Ready-to-use SSH command
terraform -chdir=terraform output ssh_command

# Ansible inventory (generated from Terraform outputs)
terraform -chdir=terraform output -raw ansible_inventory > ansible/inventory.ini
```

---

## Destroy

```bash
terraform -chdir=terraform destroy -auto-approve
```

> **Warning**: always destroy the infrastructure before deleting the repository
> or the `terraform/terraform.tfstate` file. Terraform needs its state to know what
> resources to delete. If the state is lost while resources are still running,
> they will continue to incur AWS charges and must be deleted manually from
> the AWS console.

---

## Architecture

High-level view of the target architecture and the main network flows.

```mermaid
flowchart LR
  %% Infrastructure
  subgraph AWS["AWS — eu-west-3"]
    subgraph VPC["VPC 10.0.0.0/16"]
      subgraph Subnet["Public Subnet 10.0.1.0/24 — dynamically selected AZ"]
        SG["Security Group\nSSH :22 admin only\nHTTP :80 public\nHTTPS :443 public"]
        subgraph EC2["EC2 t3.small — Ubuntu 24.04"]
          NGINX["nginx\n(host, :80/:443)"]
          subgraph Docker["Docker Compose"]
            N8N["n8n\n(:5678 localhost)"]
            PG["PostgreSQL 16\n(internal)"]
          end
          N8N <-->|SQL| PG
        end
      end
      IGW["Internet Gateway"]
      EIP["Elastic IP"]
    end
  end

  LE["Let's Encrypt"]
  User["User / Webhook"]
  Admin["Admin"]

  %% Network flows
  User -->|HTTPS :443| NGINX
  User -.->|HTTP :80 redirect| NGINX
  NGINX -->|proxy_pass :5678| N8N
  Admin -->|SSH :22| EC2
  EIP --> SG
  IGW <--> EIP
  NGINX <-->|ACME challenge| LE

  %% ---- Subgraph styling ----
  style AWS    fill:#F3F4F6,stroke:#CBD5E1,stroke-width:1px,color:#111827,font-size:15px,font-weight:bold
  style VPC    fill:#F3F4F6,stroke:#CBD5E1,stroke-width:1px,color:#111827,font-size:15px,font-weight:bold
  style Subnet fill:#F3F4F6,stroke:#CBD5E1,stroke-width:1px,color:#111827,font-size:15px,font-weight:bold
  style EC2    fill:#F3F4F6,stroke:#CBD5E1,stroke-width:1px,color:#111827,font-size:15px,font-weight:bold
  style Docker fill:#F3F4F6,stroke:#CBD5E1,stroke-width:1px,color:#111827,font-size:15px,font-weight:bold

  %% ---- Node styling ----
  classDef default  fill:#E8F1FF,stroke:#2563EB,stroke-width:1px,color:#111827;
```

The following components describe the intended v1 target architecture. At the current stage, Terraform provisions the AWS infrastructure; Ansible roles for nginx, Docker, n8n and certbot are in progress.

The target architecture includes:

* An Ubuntu 24.04 EC2 instance (`t3.small`) hosting the full stack.
* **nginx** installed on the host as a reverse proxy, handling TLS termination and proxying traffic to n8n.
* **n8n** running in Docker Compose, bound to `127.0.0.1:5678` (not exposed publicly — reachable only via nginx).
* **PostgreSQL 16** running in Docker Compose as n8n's database backend (no public port exposed).
* A **Let's Encrypt TLS certificate** obtained via certbot, with automatic renewal.
* An **Elastic IP** ensuring the public IP address remains stable across instance reboots.
* **IMDSv2 enforced** with hop limit = 1, preventing Docker containers from accessing the instance metadata service.
* **Encrypted EBS volume** (gp3) for the root disk.

---

## Terraform provisioning workflow

```mermaid
flowchart TB
  subgraph L[" Local "]
    U["Admin workstation"]
    TF["Terraform\nterraform/"]
    TFVARS["terraform.tfvars\n(local deployment values, gitignored)"]
  end

  subgraph NET["AWS Resources : Network"]
    VPC["VPC 10.0.0.0/16"]
    SUBNET["Public Subnet\n10.0.1.0/24"]
    IGW["Internet Gateway"]
    RT["Route Table\n0.0.0.0/0 → IGW"]
    SG["Security Group\nSSH :22 admin IP only\nHTTP :80 public\nHTTPS :443 public"]
  end

  subgraph COMPUTE["AWS Resources : Compute"]
    KP["Key Pair\n(SSH public key)"]
    EC2["EC2 instance\nUbuntu 24.04 — t3.small"]
    EIP["Elastic IP"]
    EIP_ASSOC["EIP Association"]
  end

  U -->|runs| TF
  TFVARS --> TF

  TF -- "create" --> VPC
  TF -- "create" --> IGW
  TF -- "create" --> SUBNET
  TF -- "create" --> RT
  TF -- "create" --> SG
  TF -- "create" --> KP
  TF -- "create" --> EC2
  TF -- "create" --> EIP
  TF -- "create" --> EIP_ASSOC

  VPC -->|contains| SUBNET
  VPC --> IGW
  RT -->|default route| IGW
  RT -->|associated with| SUBNET
  SG --> EC2
  KP --> EC2
  SUBNET -->|hosts| EC2
  EIP --> EIP_ASSOC
  EC2 --> EIP_ASSOC

  %% ---- Subgraph styling ----
  style L       fill:#F3F4F6,stroke:#949494,stroke-width:1px,color:#111827,font-size:15px,font-weight:bold
  style NET     fill:#F3F4F6,stroke:#949494,stroke-width:1px,color:#111827,font-size:15px,font-weight:bold
  style COMPUTE fill:#F3F4F6,stroke:#949494,stroke-width:1px,color:#111827,font-size:15px,font-weight:bold

  classDef default  fill:#E8F1FF,stroke:#2563EB,stroke-width:1px,color:#111827;
  classDef fileNode fill:#F3E8FF,stroke:#7C3AED,stroke-width:1px,color:#111827;

  class TFVARS fileNode;
```

---

## Security

Currently implemented at the Terraform layer:

* **SSH restricted to `admin_ip`** via the Security Group (port 22 allowed only from your `/32`).
* **EC2 key pair authentication** for the Ubuntu instance.
* **IMDSv2 enforced**: instance metadata access requires a session token (IMDSv1 disabled). Hop limit set to 1 — Docker containers cannot reach the metadata service.
* **Encrypted EBS root volume**: disk content is encrypted at rest using an AWS-managed key.

Planned at the Ansible / application layer:

* **nginx as the only public entry point** for n8n.
* **n8n not directly exposed**: n8n binds on `127.0.0.1:5678` only — accessible exclusively through nginx.
* **PostgreSQL not exposed**: no public port, reachable only by n8n within the Docker network.
* **Let's Encrypt TLS certificate** obtained via certbot, with automatic renewal.

---

## Repository structure

```text
n8n-deploy-aws/
├── ansible/                        # Configuration management (Ansible, in progress)
│   └── inventory.ini               # Generated by Terraform output (gitignored)
├── docker/                         # Docker Compose stack (planned / in progress)
├── docs/                           # Architecture documentation (planned / in progress)
├── terraform/
│   ├── compute.tf                  # EC2, EIP, key pair
│   ├── network.tf                  # VPC, subnet, IGW, route table, security group
│   ├── outputs.tf                  # Public IP, SSH command, Ansible inventory
│   ├── variables.tf                # Input variables with defaults
│   ├── versions.tf                 # Terraform and provider version constraints
│   ├── terraform.tfvars.example    # Variables template (commit-safe)
│   └── terraform.tfvars            # Actual values — gitignored, never committed
├── .gitignore
└── README.md
```

Note: the following files are local-only and intentionally ignored by Git:

* `terraform/terraform.tfstate*` and `terraform/.terraform/` — Terraform state and provider cache.
* `terraform/terraform.tfvars` — sensitive variable values (admin IP, SSH public key).
* `ansible/inventory.ini` — generated from Terraform outputs, contains the EC2 IP address.
* `.ssh/` — SSH key pair used for deployment.

---

## Future improvements

* **Ansible roles** — Docker, nginx + certbot, n8n deployment (in progress).
* **Queue mode** — Redis + n8n workers for high-volume, parallel workflow execution.
* **RDS PostgreSQL** — Replace the containerized PostgreSQL with a managed AWS RDS instance and automated S3 backups.
* **Monitoring** — Prometheus + Grafana for n8n metrics and system observability.
* **HIPAA hardening** — Encryption at rest, audit logging, network isolation checklist.
* **Multi-tenant** — Per-client n8n instances with Terraform modules.
* **Remote Terraform backend** — S3 + DynamoDB state locking for team use.

```
