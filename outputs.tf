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

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}

output "route53_zone_id" {
  description = "Route53 zone ID for tommykeyapp.com"
  value       = data.aws_route53_zone.main.zone_id
}

output "acm_certificate_arn" {
  description = "Wildcard ACM certificate ARN"
  value       = aws_acm_certificate.wildcard.arn
}

output "region" {
  description = "AWS region"
  value       = var.region
}
