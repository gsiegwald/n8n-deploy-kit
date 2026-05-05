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

