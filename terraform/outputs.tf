output "ec2_public_ip" {
  description = "Elastic IP address of the n8n EC2 instance"
  value       = aws_eip.n8n.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i .ssh/${var.project_name}_key ubuntu@${aws_eip.n8n.public_ip}"
}

# Generates the Ansible inventory file content.
# Use: terraform output -raw ansible_inventory > ansible/inventory.ini
output "ansible_inventory" {
  description = "Ansible inventory file content — pipe to ansible/inventory.ini"
  value       = <<-INI
    [n8n]
    ${aws_eip.n8n.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=.ssh/${var.project_name}_key
  INI
}

