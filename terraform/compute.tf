resource "aws_key_pair" "admin" {
  key_name   = "${var.project_name}-admin-key"
  public_key = var.ssh_public_key
}

data "aws_ssm_parameter" "ubuntu_2404_ami" {
  name = "/aws/service/canonical/ubuntu/server/noble/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_instance" "n8n" {
  ami                    = data.aws_ssm_parameter.ubuntu_2404_ami.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.n8n.id]
  key_name               = aws_key_pair.admin.key_name

  # Enforce IMDSv2 (token-required) and prevent Docker containers
  # from reaching the instance metadata service (hop limit = 1).
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name    = "${var.project_name}-ec2"
    Project = var.project_name
  }
}

resource "aws_eip" "n8n" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.gw]

  tags = {
    Name    = "${var.project_name}-eip"
    Project = var.project_name
  }
}

resource "aws_eip_association" "n8n" {
  allocation_id = aws_eip.n8n.id
  instance_id   = aws_instance.n8n.id
}

