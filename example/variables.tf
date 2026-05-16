variable "ssh_user" {
  description = "SSH user with passwordless sudo"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31.0"
}

variable "pod_cidr" {
  description = "Pod network CIDR"
  type        = string
  default     = "10.200.0.0/16"
}

variable "service_cidr" {
  description = "Service network CIDR"
  type        = string
  default     = "10.32.0.0/24"
}

variable "enable_traefik" {
  description = "Deploy Traefik ingress controller"
  type        = bool
  default     = true
}

variable "enable_kyverno" {
  description = "Deploy Kyverno policy engine"
  type        = bool
  default     = true
}

variable "enable_trivy" {
  description = "Deploy Trivy vulnerability scanner"
  type        = bool
  default     = true
}
