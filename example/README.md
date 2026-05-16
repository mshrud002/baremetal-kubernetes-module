# BareMetal Kubernetes Module Example

This example provisions a 3-controller, 3-worker Kubernetes cluster with Traefik, Kyverno, and Trivy.

## Prerequisites

- 6 bare metal machines (or VMs) with Ubuntu/Debian and SSH access
- Terraform >= 1.5 installed
- SSH key-based access to all nodes

## Usage

```bash
# 1. Copy and edit the variables file
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# 2. Initialize and apply
terraform init
terraform apply

# 3. Use the cluster
export KUBECONFIG=$(terraform output -raw kubeconfig)
kubectl get nodes
```

## Node Requirements

| Role | Count | Spec |
|------|-------|------|
| Controller | 3 | 2+ vCPU, 4+ GB RAM, 20+ GB disk |
| Worker | 3 | 4+ vCPU, 8+ GB RAM, 40+ GB disk |

All nodes must have:
- Static IP addresses (set in `controllers` and `workers`)
- SSH user with passwordless sudo access
- Network connectivity between all nodes
- Internet access (for downloading binaries)
- Ubuntu 22.04+ or Debian 12+ recommended
