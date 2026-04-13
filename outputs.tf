output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "k3s_public_ip" {
  description = "K3s server Elastic IP"
  value       = aws_eip.k3s.public_ip
}

output "k3s_instance_id" {
  description = "K3s EC2 instance ID"
  value       = aws_instance.k3s.id
}

output "k3s_security_group_id" {
  description = "K3s security group ID"
  value       = aws_security_group.k3s.id
}

output "k3s_iam_role_name" {
  description = "K3s IAM role name (for attaching additional policies)"
  value       = aws_iam_role.k3s.name
}

output "region" {
  description = "AWS region"
  value       = var.region
}
