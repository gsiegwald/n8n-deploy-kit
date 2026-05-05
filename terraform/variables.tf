variable "aws_region" {
  description = "AWS region where the infrastructure will be deployed"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Project name — used for resource naming and tags"
  type        = string
  default     = "n8n-deploy-aws"
}

variable "admin_ip" {
  description = "Your public IP address with CIDR suffix (/32) — SSH access is restricted to this IP"
  type        = string
  sensitive   = true

  validation {
    condition     = can(cidrhost(var.admin_ip, 0)) && var.admin_ip != "0.0.0.0/0"
    error_message = "admin_ip must be a valid CIDR block, for example 203.0.113.10/32, and must not be 0.0.0.0/0."
  }
}

variable "ssh_public_key" {
  description = "SSH public key content — used to create the EC2 key pair"
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "EC2 instance type — t3.small recommended minimum for n8n + PostgreSQL"
  type        = string
  default     = "t3.small"
}

