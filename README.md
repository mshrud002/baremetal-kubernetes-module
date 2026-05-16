# BareMetal Kubernetes Module

A Terraform module that provisions a **Kubernetes cluster on bare metal** following the **"Kubernetes the Hard Way"** approach, with built-in addons for ingress, security scanning, and policy management.

## Project Structure

```
baremetal-kubernetes-module/
├── module/               # Reusable Terraform module
│   ├── main.tf           # Core resources (TLS, etcd, control plane, workers)
│   ├── variables.tf      # Module input variables
│   ├── outputs.tf        # Module output values
│   ├── addons.tf         # Helm-based addons (Traefik, Kyverno, Trivy)
│   ├── templates/        # Systemd service + Kubernetes YAML templates
│   └── .generated/       # Generated kubeconfig and encryption config
├── example/              # Example usage
│   ├── main.tf           # Example Terraform config
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
└── README.md
```

## Architecture

The module automates the full KTHW stack:

| Layer | Components |
|-------|-----------|
| **PKI** | CA, admin, API/etcd server, controller-manager, scheduler, kube-proxy, kubelet (per worker), service account |
| **Data Store** | Clustered etcd on all controllers (TLS peer & client auth) |
| **Control Plane** | kube-apiserver, kube-controller-manager, kube-scheduler as systemd services |
| **Workers** | containerd + runc + CNI bridge + kubelet + kube-proxy with per-worker `/24` pod subnets |
| **Networking** | Bridge CNI with host-local IPAM, per-worker pod CIDR allocation |
| **DNS** | CoreDNS deployed as a Deployment in kube-system |
| **Addons** | Traefik ingress, Kyverno policy engine, Trivy vulnerability scanner |

## Addons

| Addon | Function | Installed via | Default |
|-------|----------|---------------|---------|
| **Traefik** | Ingress controller with default IngressClass | Helm chart | Enabled (NodePort) |
| **Kyverno** | Kubernetes policy engine (validating webhook) | Helm chart | Enabled (Audit mode) |
| **Trivy** | Container image vulnerability scanner (operator) | Helm chart | Enabled |
| **Karpenter** | Node autoscaler (requires provisioning backend) | Helm chart | Disabled |

### Traefik
- Installed as the default IngressClass (any Ingress without explicit `ingressClassName` uses Traefik)
- Service type: `NodePort` (ports 30080/30443) for bare metal
- Set `traefik_service_type = "LoadBalancer"` if using MetalLB

### Kyverno
- Ships with 3 sample policies:
  - `disallow-latest-tag` - Blocks `:latest` image tags
  - `require-resource-limits` - Ensures CPU/memory limits and requests
  - `require-readiness-probe` - Ensures readiness probes on all pods
- Set `kyverno_policy_enforce = true` to switch from Audit to Enforce mode

### Trivy
- Scans all container images in the cluster via the Trivy Operator
- Results stored as `VulnerabilityReport` CRDs per namespace
- View reports: `kubectl get vulnerabilityreports --all-namespaces`

### Karpenter
- Disabled by default; requires a provisioning backend (AWS, MAAS, vSphere, etc.)
- For bare metal, pair with MAAS or vSphere with a custom provisioner

## Quick Start

```bash
# Using the example
cd example

# Configure your nodes
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# Deploy
terraform init
terraform apply

# Use the cluster
export KUBECONFIG=$(terraform output -raw kubeconfig)
kubectl get nodes -o wide
kubectl get pods -n kube-system
kubectl get pods -n traefik
kubectl get pods -n kyverno
kubectl get vulnerabilityreports --all-namespaces 2>/dev/null
```

## Using as a Module

```hcl
module "kubernetes" {
  source = "./module"

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

  ssh_user             = "ubuntu"
  ssh_private_key_path = "~/.ssh/id_rsa"
}
```

From a Git repository:

```hcl
module "kubernetes" {
  source = "github.com/your-org/baremetal-kubernetes-module//module"
  ...
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| tls | ~> 4.0 |
| null | ~> 3.2 |
| random | ~> 3.6 |
| local | ~> 2.5 |

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| controllers | Controller node hostnames and IPs | `list(object({hostname, ip}))` | - |
| workers | Worker node hostnames and IPs | `list(object({hostname, ip}))` | - |
| ssh_user | SSH user with passwordless sudo | `string` | - |
| ssh_private_key_path | Path to SSH private key | `string` | - |
| cluster_name | Kubernetes cluster name | `string` | `"kubernetes"` |
| pod_cidr | Pod network CIDR | `string` | `"10.200.0.0/16"` |
| service_cidr | Service network CIDR | `string` | `"10.32.0.0/24"` |
| kubernetes_version | Kubernetes version | `string` | `"1.31.0"` |
| etcd_version | etcd version | `string` | `"3.5.15"` |
| containerd_version | containerd version | `string` | `"1.7.22"` |
| runc_version | runc version | `string` | `"1.2.0"` |
| cni_plugins_version | CNI plugins version | `string` | `"1.5.1"` |
| cni_plugin | CNI plugin (flannel or calico) | `string` | `"flannel"` |
| dns_domain | Cluster DNS domain | `string` | `"cluster.local"` |
| api_server_load_balancer | Optional load balancer address | `string` | `""` |
| enable_traefik | Deploy Traefik ingress controller | `bool` | `true` |
| enable_kyverno | Deploy Kyverno policy engine | `bool` | `true` |
| enable_trivy | Deploy Trivy vulnerability scanner | `bool` | `true` |
| enable_karpenter | Deploy Karpenter autoscaler | `bool` | `false` |
| traefik_service_type | Traefik service type | `string` | `"NodePort"` |
| kyverno_policy_enforce | Enforce vs audit mode | `bool` | `false` |

## Outputs

| Name | Description |
|------|-------------|
| api_server_url | Kubernetes API server URL |
| admin_kubeconfig_path | Path to admin kubeconfig (in `module/.generated/`) |
| controller_ips | Controller node IPs |
| worker_ips | Worker node IPs |
| addons | Map of deployed addon status |
| traefik_ingress_class | Traefik IngressClass name (if enabled) |
| kyverno_policies | Kyverno enforcement mode (if enabled) |

## Generated Files

- `module/.generated/admin.kubeconfig` - Admin kubeconfig for kubectl
- `module/.generated/encryption-config.yaml` - Encryption at rest config

## Node Requirements

| Role | Count | Spec |
|------|-------|------|
| Controller | 3 | 2+ vCPU, 4+ GB RAM, 20+ GB disk |
| Worker | 3+ | 4+ vCPU, 8+ GB RAM, 40+ GB disk |

All nodes require:
- Static IP addresses
- SSH user with passwordless sudo
- Full network connectivity between all nodes
- Internet access for downloading binaries
- Ubuntu 22.04+ or Debian 12+ (systemd-based)

## Notes

- This module does NOT provision VMs/machines; bare metal nodes must exist with SSH access
- All certs and keys are stored in Terraform state (marked sensitive)
- Use `terraform destroy` to stop services (does not clean up downloaded binaries)
- For production, configure an external load balancer for the API server
