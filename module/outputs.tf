output "api_server_url" {
  description = "Kubernetes API server URL"
  value       = local.api_server_url
}

output "admin_kubeconfig_path" {
  description = "Path to the admin kubeconfig file"
  value       = abspath(local_file.admin_kubeconfig.filename)
}

output "controller_ips" {
  description = "Controller node IP addresses"
  value       = [for c in var.controllers : c.ip]
}

output "worker_ips" {
  description = "Worker node IP addresses"
  value       = [for w in var.workers : w.ip]
}

output "ca_cert_pem" {
  description = "CA certificate PEM"
  value       = tls_self_signed_cert.ca.cert_pem
  sensitive   = true
}

output "addons" {
  description = "Deployed addon status"
  value = {
    traefik   = var.enable_traefik
    kyverno   = var.enable_kyverno
    trivy     = var.enable_trivy
    karpenter = var.enable_karpenter
  }
}

output "traefik_ingress_class" {
  description = "Default IngressClass name"
  value       = var.enable_traefik ? "traefik" : null
}

output "kyverno_policies" {
  description = "Kyverno policy enforcement mode"
  value       = var.enable_kyverno ? (var.kyverno_policy_enforce ? "Enforce" : "Audit") : null
}
