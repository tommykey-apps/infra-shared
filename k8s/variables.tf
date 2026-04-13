variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project" {
  description = "Project name prefix"
  type        = string
  default     = "shared"
}

variable "argocd_domain" {
  description = "Domain for ArgoCD WebUI"
  type        = string
  default     = "argocd.tommykeyapp.com"
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate"
  type        = string
  default     = "admin@tommykeyapp.com"
}

variable "argocd_admin_password_hash" {
  description = "Bcrypt hash of ArgoCD admin password"
  type        = string
  default     = "$2b$10$Qn1f00M1FNxq/4knyXGlFOxpmc2sDkmWQlybmGRqq6MH5vCdEb4ta"
}
