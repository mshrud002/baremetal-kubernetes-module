output "kubeconfig" {
  description = "Path to admin kubeconfig"
  value       = module.baremetal_k8s.admin_kubeconfig_path
}

output "api_server" {
  description = "API server URL"
  value       = module.baremetal_k8s.api_server_url
}

output "nodes" {
  description = "Cluster node IPs"
  value = {
    controllers = module.baremetal_k8s.controller_ips
    workers     = module.baremetal_k8s.worker_ips
  }
}

output "addons" {
  description = "Deployed addon status"
  value       = module.baremetal_k8s.addons
}

output "ingress_class" {
  description = "Default IngressClass"
  value       = module.baremetal_k8s.traefik_ingress_class
}
