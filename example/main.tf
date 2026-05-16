terraform {
  required_version = ">= 1.5"
}

module "baremetal_k8s" {
  source = "../module"

  controllers = [
    { hostname = "controller-0", ip = "10.0.0.10" },
    { hostname = "controller-1", ip = "10.0.0.11" },
    { hostname = "controller-2", ip = "10.0.0.12" },
  ]

  workers = [
    { hostname = "worker-0", ip = "10.0.0.20" },
    { hostname = "worker-1", ip = "10.0.0.21" },
    { hostname = "worker-2", ip = "10.0.0.22" },
  ]

  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path

  kubernetes_version = var.kubernetes_version
  pod_cidr           = var.pod_cidr
  service_cidr       = var.service_cidr

  enable_traefik = var.enable_traefik
  enable_kyverno = var.enable_kyverno
  enable_trivy   = var.enable_trivy
}
