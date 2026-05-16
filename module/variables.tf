variable "controllers" {
  description = "Controller node hostnames and IPs"
  type = list(object({
    hostname = string
    ip       = string
  }))
}

variable "workers" {
  description = "Worker node hostnames and IPs"
  type = list(object({
    hostname = string
    ip       = string
  }))
}

variable "ssh_user" {
  description = "SSH user for connecting to nodes (must have passwordless sudo)"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for node access"
  type        = string
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "kubernetes"
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

variable "kubernetes_version" {
  description = "Kubernetes release version"
  type        = string
  default     = "1.31.0"
}

variable "etcd_version" {
  description = "etcd release version"
  type        = string
  default     = "3.5.15"
}

variable "containerd_version" {
  description = "containerd release version"
  type        = string
  default     = "1.7.22"
}

variable "runc_version" {
  description = "runc release version"
  type        = string
  default     = "1.2.0"
}

variable "cni_plugins_version" {
  description = "CNI plugins release version"
  type        = string
  default     = "1.5.1"
}

variable "cni_plugin" {
  description = "CNI plugin (flannel or calico)"
  type        = string
  default     = "flannel"
  validation {
    condition     = contains(["flannel", "calico"], var.cni_plugin)
    error_message = "cni_plugin must be 'flannel' or 'calico'"
  }
}

variable "dns_domain" {
  description = "Cluster DNS domain"
  type        = string
  default     = "cluster.local"
}

variable "api_server_load_balancer" {
  description = "External load balancer address for API server (optional)"
  type        = string
  default     = ""
}

variable "kubernetes_config_dir" {
  description = "Config directory on controller nodes"
  type        = string
  default     = "/var/lib/kubernetes"
}

variable "etcd_data_dir" {
  description = "etcd data directory"
  type        = string
  default     = "/var/lib/etcd"
}

variable "bin_dir" {
  description = "Binary installation directory"
  type        = string
  default     = "/usr/local/bin"
}

# ============================================================================
# ADDON VARIABLES
# ============================================================================

variable "enable_traefik" {
  description = "Deploy Traefik as the default ingress controller"
  type        = bool
  default     = true
}

variable "enable_kyverno" {
  description = "Deploy Kyverno policy engine"
  type        = bool
  default     = true
}

variable "enable_trivy" {
  description = "Deploy Trivy Operator for container image vulnerability scanning"
  type        = bool
  default     = true
}

variable "enable_karpenter" {
  description = "Deploy Karpenter node autoscaler (requires provisioning backend)"
  type        = bool
  default     = false
}

variable "traefik_service_type" {
  description = "Traefik service type (NodePort, ClusterIP, or LoadBalancer)"
  type        = string
  default     = "NodePort"
  validation {
    condition     = contains(["NodePort", "ClusterIP", "LoadBalancer"], var.traefik_service_type)
    error_message = "traefik_service_type must be NodePort, ClusterIP, or LoadBalancer"
  }
}

variable "kyverno_policy_enforce" {
  description = "Set Kyverno policies to enforce mode vs audit mode"
  type        = bool
  default     = false
}
