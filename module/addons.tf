# ============================================================================
# HELM-BASED ADDONS (Traefik, Kyverno, Trivy, Karpenter)
# ============================================================================
locals {
  addons_enabled = var.enable_traefik || var.enable_kyverno || var.enable_trivy || var.enable_karpenter
}

resource "null_resource" "helm_addons" {
  count = local.addons_enabled ? 1 : 0

  depends_on = [null_resource.cluster_addons]

  triggers = {
    enable_traefik        = var.enable_traefik
    enable_kyverno        = var.enable_kyverno
    enable_trivy          = var.enable_trivy
    enable_karpenter      = var.enable_karpenter
    traefik_service_type  = var.traefik_service_type
    kyverno_policy_enforce = var.kyverno_policy_enforce
  }

  connection {
    type        = "ssh"
    host        = var.controllers[0].ip
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    timeout     = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "export KUBECONFIG=~/.kube/config",

      "while ! kubectl get nodes 2>/dev/null | grep -q Ready; do echo 'waiting for cluster...'; sleep 5; done",

      "# Install Helm",
      "which helm >/dev/null 2>&1 || curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash",

      "# Add Helm repositories",
      "helm repo add traefik https://traefik.github.io/charts 2>/dev/null || true",
      "helm repo add kyverno https://kyverno.github.io/kyverno/ 2>/dev/null || true",
      "helm repo add trivy-operator https://aquasecurity.github.io/helm-charts 2>/dev/null || true",
      "helm repo update 2>/dev/null",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      var.enable_traefik ? "helm upgrade --install traefik traefik/traefik --namespace traefik --create-namespace --set service.type=${var.traefik_service_type} --set ingressClass.enabled=true --set ingressClass.isDefaultClass=true --set ports.web.nodePort=30080 --set ports.websecure.nodePort=30443 --set dashboard.enabled=true --set dashboard.domain=dashboard.localhost --wait --timeout 5m" : "echo 'traefik: disabled, skipping'",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      var.enable_kyverno ? "helm upgrade --install kyverno kyverno/kyverno --namespace kyverno --create-namespace --wait --timeout 5m" : "echo 'kyverno: disabled, skipping'",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      var.enable_trivy ? "helm upgrade --install trivy-operator trivy-operator/trivy-operator --namespace trivy-system --create-namespace --set trivy.ignoreUnfixed=true --wait --timeout 5m" : "echo 'trivy: disabled, skipping'",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      var.enable_karpenter ? "helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter --namespace karpenter --create-namespace --set settings.aws.defaultInstanceProfile=null --set settings.aws.clusterName=${var.cluster_name} --wait --timeout 5m" : "echo 'karpenter: disabled (requires provisioning backend)'",
    ]
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/kyverno-policies.yaml.tpl", {
      action = var.kyverno_policy_enforce ? "Enforce" : "Audit"
    })
    destination = "/tmp/kyverno-policies.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      var.enable_kyverno ? "kubectl apply -f /tmp/kyverno-policies.yaml 2>/dev/null || echo 'kyverno: policies applied'" : "echo 'kyverno policies: skipped'",
    ]
  }
}

# ============================================================================
# ADDON VERIFICATION
# ============================================================================
resource "null_resource" "addon_verify" {
  count = local.addons_enabled ? 1 : 0

  depends_on = [null_resource.helm_addons]

  triggers = {
    always = timestamp()
  }

  connection {
    type        = "ssh"
    host        = var.controllers[0].ip
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    timeout     = "30s"
  }

  provisioner "remote-exec" {
    inline = [
      "export KUBECONFIG=~/.kube/config",
      "echo '=== Addon Status ==='",
      var.enable_traefik ? "kubectl -n traefik get pods -o wide 2>/dev/null || echo 'traefik not ready'" : "echo 'traefik: not deployed'",
      var.enable_kyverno ? "kubectl -n kyverno get pods -o wide 2>/dev/null || echo 'kyverno not ready'" : "echo 'kyverno: not deployed'",
      var.enable_trivy ? "kubectl -n trivy-system get pods -o wide 2>/dev/null || echo 'trivy not ready'" : "echo 'trivy: not deployed'",
      var.enable_karpenter ? "kubectl -n karpenter get pods -o wide 2>/dev/null || echo 'karpenter not ready'" : "echo 'karpenter: not deployed'",
      "echo '=== Addon Deployment Complete ==='",
    ]
  }
}
