terraform {
  required_version = ">= 1.5"
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

locals {
  controllers_map     = { for c in var.controllers : c.hostname => c }
  workers_map         = { for w in var.workers : w.hostname => w }
  kubernetes_service_ip = cidrhost(var.service_cidr, 1)
  dns_service_ip        = cidrhost(var.service_cidr, 10)

  etcd_initial_cluster = join(",", [
    for c in var.controllers : "${c.hostname}=https://${c.ip}:2380"
  ])

  etcd_server_list = join(",", [
    for c in var.controllers : "https://${c.ip}:2379"
  ])

  api_server_dns_names = concat(
    [
      "kubernetes", "kubernetes.default", "kubernetes.default.svc",
      "kubernetes.default.svc.${var.dns_domain}", "localhost"
    ],
    [for c in var.controllers : c.hostname]
  )

  api_server_ip_addresses = concat(
    [for c in var.controllers : c.ip],
    [local.kubernetes_service_ip, "127.0.0.1"]
  )

  api_server_url = var.api_server_load_balancer != "" ?
    "https://${var.api_server_load_balancer}:6443" :
    "https://${var.controllers[0].ip}:6443"

  # Each worker gets a /24 subnet from the pod CIDR
  worker_pod_cidrs = {
    for i, w in var.workers : w.hostname => cidrsubnet(var.pod_cidr, 8, i)
  }
}

# ============================================================================
# TLS CERTIFICATE AUTHORITY
# ============================================================================
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "Kubernetes CA"
    organization = "Kubernetes"
  }

  validity_period_hours = 87600
  is_ca_certificate     = true

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_sign",
    "crl_sign",
  ]
}

# ============================================================================
# TLS ADMIN CLIENT CERTIFICATE
# ============================================================================
resource "tls_private_key" "admin" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "admin" {
  private_key_pem = tls_private_key.admin.private_key_pem

  subject {
    common_name  = "admin"
    organization = "system:masters"
  }
}

resource "tls_locally_signed_cert" "admin" {
  cert_request_pem   = tls_cert_request.admin.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 87600

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

# ============================================================================
# TLS KUBE-API-SERVER CERTIFICATE (also used for etcd)
# ============================================================================
resource "tls_private_key" "kube_api_server" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "kube_api_server" {
  private_key_pem = tls_private_key.kube_api_server.private_key_pem

  subject {
    common_name  = "kubernetes"
    organization = "Kubernetes"
  }

  dns_names    = local.api_server_dns_names
  ip_addresses = local.api_server_ip_addresses
}

resource "tls_locally_signed_cert" "kube_api_server" {
  cert_request_pem   = tls_cert_request.kube_api_server.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 87600

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

# ============================================================================
# TLS KUBE-CONTROLLER-MANAGER CERTIFICATE
# ============================================================================
resource "tls_private_key" "kube_controller_manager" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "kube_controller_manager" {
  private_key_pem = tls_private_key.kube_controller_manager.private_key_pem

  subject {
    common_name  = "system:kube-controller-manager"
    organization = "system:kube-controller-manager"
  }
}

resource "tls_locally_signed_cert" "kube_controller_manager" {
  cert_request_pem   = tls_cert_request.kube_controller_manager.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 87600

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

# ============================================================================
# TLS KUBE-SCHEDULER CERTIFICATE
# ============================================================================
resource "tls_private_key" "kube_scheduler" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "kube_scheduler" {
  private_key_pem = tls_private_key.kube_scheduler.private_key_pem

  subject {
    common_name  = "system:kube-scheduler"
    organization = "system:kube-scheduler"
  }
}

resource "tls_locally_signed_cert" "kube_scheduler" {
  cert_request_pem   = tls_cert_request.kube_scheduler.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 87600

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

# ============================================================================
# TLS KUBE-PROXY CERTIFICATE
# ============================================================================
resource "tls_private_key" "kube_proxy" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "kube_proxy" {
  private_key_pem = tls_private_key.kube_proxy.private_key_pem

  subject {
    common_name  = "system:kube-proxy"
    organization = "system:node-proxier"
  }
}

resource "tls_locally_signed_cert" "kube_proxy" {
  cert_request_pem   = tls_cert_request.kube_proxy.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 87600

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

# ============================================================================
# TLS SERVICE ACCOUNT KEY PAIR
# ============================================================================
resource "tls_private_key" "service_account" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_public_key" "service_account" {
  private_key_pem = tls_private_key.service_account.private_key_pem
}

# ============================================================================
# TLS KUBELET CERTIFICATES (one per worker)
# ============================================================================
resource "tls_private_key" "kubelet" {
  for_each  = local.workers_map
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "kubelet" {
  for_each = local.workers_map

  private_key_pem = tls_private_key.kubelet[each.key].private_key_pem

  subject {
    common_name  = each.value.hostname
    organization = "system:nodes"
  }

  dns_names    = [each.value.hostname]
  ip_addresses = [each.value.ip]
}

resource "tls_locally_signed_cert" "kubelet" {
  for_each = local.workers_map

  cert_request_pem   = tls_cert_request.kubelet[each.key].cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 87600

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

# ============================================================================
# ENCRYPTION CONFIG
# ============================================================================
resource "random_id" "encryption_key" {
  byte_length = 32
}

resource "local_file" "encryption_config" {
  content = templatefile("${path.module}/templates/encryption-config.yaml.tpl", {
    encryption_key = random_id.encryption_key.b64_std
  })
  filename = "${path.module}/.generated/encryption-config.yaml"
}

# ============================================================================
# ADMIN KUBECONFIG
# ============================================================================
resource "local_file" "admin_kubeconfig" {
  content = templatefile("${path.module}/templates/kubeconfig.tpl", {
    ca_cert     = tls_self_signed_cert.ca.cert_pem
    server      = local.api_server_url
    user        = "admin"
    client_cert = tls_locally_signed_cert.admin.cert_pem
    client_key  = tls_private_key.admin.private_key_pem
  })
  filename = "${path.module}/.generated/admin.kubeconfig"
}

# ============================================================================
# ETCD DEPLOYMENT
# ============================================================================
resource "null_resource" "etcd" {
  for_each = local.controllers_map

  triggers = {
    node_ip          = each.value.ip
    etcd_version     = var.etcd_version
    etcd_initial_cluster = local.etcd_initial_cluster
  }

  connection {
    type        = "ssh"
    host        = each.value.ip
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    timeout     = "30s"
  }

  provisioner "file" {
    content     = tls_self_signed_cert.ca.cert_pem
    destination = "/tmp/ca.pem"
  }

  provisioner "file" {
    content     = tls_locally_signed_cert.kube_api_server.cert_pem
    destination = "/tmp/kubernetes.pem"
  }

  provisioner "file" {
    content     = tls_private_key.kube_api_server.private_key_pem
    destination = "/tmp/kubernetes-key.pem"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/etcd.service.tpl", {
      bin_dir          = var.bin_dir
      name             = each.value.hostname
      internal_ip      = each.value.ip
      initial_cluster  = local.etcd_initial_cluster
    })
    destination = "/tmp/etcd.service"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/etcd /var/lib/etcd",
      "sudo mv /tmp/ca.pem /etc/etcd/",
      "sudo mv /tmp/kubernetes.pem /etc/etcd/",
      "sudo mv /tmp/kubernetes-key.pem /etc/etcd/",
      "sudo chmod 600 /etc/etcd/*-key.pem",
      "sudo chown root:root /etc/etcd/*",

      "wget -q --show-progress --https-only --timestamping \"https://github.com/etcd-io/etcd/releases/download/v${var.etcd_version}/etcd-v${var.etcd_version}-linux-amd64.tar.gz\"",
      "tar xf etcd-v${var.etcd_version}-linux-amd64.tar.gz",
      "sudo mv etcd-v${var.etcd_version}-linux-amd64/etcd* ${var.bin_dir}/",
      "rm -rf etcd-v${var.etcd_version}-linux-amd64*",

      "sudo mv /tmp/etcd.service /etc/systemd/system/",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable etcd",
      "sudo systemctl start etcd",
      "sleep 3",
      "sudo ETCDCTL_API=3 ${var.bin_dir}/etcdctl member list --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem",
    ]
  }
}

# ============================================================================
# CONTROL PLANE DEPLOYMENT
# ============================================================================
resource "null_resource" "control_plane" {
  for_each = local.controllers_map

  depends_on = [null_resource.etcd]

  triggers = {
    node_ip            = each.value.ip
    kubernetes_version = var.kubernetes_version
    service_cidr       = var.service_cidr
    pod_cidr           = var.pod_cidr
  }

  connection {
    type        = "ssh"
    host        = each.value.ip
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    timeout     = "30s"
  }

  provisioner "file" {
    content     = tls_self_signed_cert.ca.cert_pem
    destination = "/tmp/ca.pem"
  }

  provisioner "file" {
    content     = tls_private_key.ca.private_key_pem
    destination = "/tmp/ca-key.pem"
  }

  provisioner "file" {
    content     = tls_locally_signed_cert.kube_api_server.cert_pem
    destination = "/tmp/kubernetes.pem"
  }

  provisioner "file" {
    content     = tls_private_key.kube_api_server.private_key_pem
    destination = "/tmp/kubernetes-key.pem"
  }

  provisioner "file" {
    content     = tls_private_key.service_account.private_key_pem
    destination = "/tmp/service-account-key.pem"
  }

  provisioner "file" {
    content     = tls_public_key.service_account.public_key_pem
    destination = "/tmp/service-account.pub"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/kubeconfig.tpl", {
      ca_cert     = tls_self_signed_cert.ca.cert_pem
      server      = local.api_server_url
      user        = "system:kube-controller-manager"
      client_cert = tls_locally_signed_cert.kube_controller_manager.cert_pem
      client_key  = tls_private_key.kube_controller_manager.private_key_pem
    })
    destination = "/tmp/kube-controller-manager.kubeconfig"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/kubeconfig.tpl", {
      ca_cert     = tls_self_signed_cert.ca.cert_pem
      server      = local.api_server_url
      user        = "system:kube-scheduler"
      client_cert = tls_locally_signed_cert.kube_scheduler.cert_pem
      client_key  = tls_private_key.kube_scheduler.private_key_pem
    })
    destination = "/tmp/kube-scheduler.kubeconfig"
  }

  provisioner "file" {
    content     = local_file.encryption_config.content
    destination = "/tmp/encryption-config.yaml"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/kube-apiserver.service.tpl", {
      bin_dir                = var.bin_dir
      advertise_address      = each.value.ip
      apiserver_count        = length(var.controllers)
      etcd_servers           = local.etcd_server_list
      kubernetes_config_dir  = var.kubernetes_config_dir
      service_cidr           = var.service_cidr
      kubernetes_service_ip  = local.kubernetes_service_ip
    })
    destination = "/tmp/kube-apiserver.service"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/kube-controller-manager.service.tpl", {
      bin_dir               = var.bin_dir
      kubernetes_config_dir = var.kubernetes_config_dir
      pod_cidr              = var.pod_cidr
      service_cidr          = var.service_cidr
      cluster_name          = var.cluster_name
    })
    destination = "/tmp/kube-controller-manager.service"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/kube-scheduler.service.tpl", {
      bin_dir               = var.bin_dir
      kubernetes_config_dir = var.kubernetes_config_dir
    })
    destination = "/tmp/kube-scheduler.service"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${var.kubernetes_config_dir}",
      "sudo mv /tmp/ca.pem ${var.kubernetes_config_dir}/",
      "sudo mv /tmp/ca-key.pem ${var.kubernetes_config_dir}/",
      "sudo mv /tmp/kubernetes.pem ${var.kubernetes_config_dir}/",
      "sudo mv /tmp/kubernetes-key.pem ${var.kubernetes_config_dir}/",
      "sudo mv /tmp/service-account-key.pem ${var.kubernetes_config_dir}/",
      "sudo mv /tmp/service-account.pub ${var.kubernetes_config_dir}/",
      "sudo mv /tmp/kube-controller-manager.kubeconfig ${var.kubernetes_config_dir}/",
      "sudo mv /tmp/kube-scheduler.kubeconfig ${var.kubernetes_config_dir}/",
      "sudo mv /tmp/encryption-config.yaml ${var.kubernetes_config_dir}/",
      "sudo mv /tmp/kube-apiserver.service /etc/systemd/system/",
      "sudo mv /tmp/kube-controller-manager.service /etc/systemd/system/",
      "sudo mv /tmp/kube-scheduler.service /etc/systemd/system/",
      "sudo chmod 600 ${var.kubernetes_config_dir}/*-key.pem ${var.kubernetes_config_dir}/*.kubeconfig",
      "sudo chown root:root ${var.kubernetes_config_dir}/*",

      "wget -q --show-progress --https-only --timestamping \"https://dl.k8s.io/release/v${var.kubernetes_version}/bin/linux/amd64/kube-apiserver\"",
      "wget -q --show-progress --https-only --timestamping \"https://dl.k8s.io/release/v${var.kubernetes_version}/bin/linux/amd64/kube-controller-manager\"",
      "wget -q --show-progress --https-only --timestamping \"https://dl.k8s.io/release/v${var.kubernetes_version}/bin/linux/amd64/kube-scheduler\"",
      "wget -q --show-progress --https-only --timestamping \"https://dl.k8s.io/release/v${var.kubernetes_version}/bin/linux/amd64/kubectl\"",
      "chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl",
      "sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl ${var.bin_dir}/",

      "sudo systemctl daemon-reload",
      "sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler",
      "sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler",
    ]
  }
}

# ============================================================================
# WORKER NODE DEPLOYMENT
# ============================================================================
resource "null_resource" "worker" {
  for_each = local.workers_map

  depends_on = [null_resource.control_plane]

  triggers = {
    node_ip             = each.value.ip
    kubernetes_version  = var.kubernetes_version
    containerd_version  = var.containerd_version
    runc_version        = var.runc_version
    cni_plugins_version = var.cni_plugins_version
    pod_cidr            = var.pod_cidr
  }

  connection {
    type        = "ssh"
    host        = each.value.ip
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    timeout     = "30s"
  }

  provisioner "file" {
    content     = tls_self_signed_cert.ca.cert_pem
    destination = "/tmp/ca.pem"
  }

  provisioner "file" {
    content     = tls_locally_signed_cert.kubelet[each.key].cert_pem
    destination = "/tmp/${each.value.hostname}.pem"
  }

  provisioner "file" {
    content     = tls_private_key.kubelet[each.key].private_key_pem
    destination = "/tmp/${each.value.hostname}-key.pem"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/kubeconfig.tpl", {
      ca_cert     = tls_self_signed_cert.ca.cert_pem
      server      = local.api_server_url
      user        = each.value.hostname
      client_cert = tls_locally_signed_cert.kubelet[each.key].cert_pem
      client_key  = tls_private_key.kubelet[each.key].private_key_pem
    })
    destination = "/tmp/kubelet.kubeconfig"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/kubeconfig.tpl", {
      ca_cert     = tls_self_signed_cert.ca.cert_pem
      server      = local.api_server_url
      user        = "system:kube-proxy"
      client_cert = tls_locally_signed_cert.kube_proxy.cert_pem
      client_key  = tls_private_key.kube_proxy.private_key_pem
    })
    destination = "/tmp/kube-proxy.kubeconfig"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/kube-proxy-config.yaml.tpl", {
      cluster_cidr    = var.pod_cidr
      kubeconfig_path = "/var/lib/kube-proxy/kubeconfig"
    })
    destination = "/tmp/kube-proxy-config.yaml"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/kubelet.service.tpl", {
      bin_dir = var.bin_dir
    })
    destination = "/tmp/kubelet.service"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/kube-proxy.service.tpl", {
      bin_dir = var.bin_dir
    })
    destination = "/tmp/kube-proxy.service"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/containerd.service.tpl", {
      bin_dir = var.bin_dir
    })
    destination = "/tmp/containerd.service"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/cni/bin /etc/cni/net.d /var/lib/kubelet /var/lib/kube-proxy /etc/containerd",

      "sudo mv /tmp/ca.pem /var/lib/kubelet/",
      "sudo mv /tmp/${each.value.hostname}.pem /var/lib/kubelet/",
      "sudo mv /tmp/${each.value.hostname}-key.pem /var/lib/kubelet/",
      "sudo mv /tmp/kubelet.kubeconfig /var/lib/kubelet/",
      "sudo mv /tmp/kube-proxy.kubeconfig /var/lib/kube-proxy/",
      "sudo mv /tmp/kube-proxy-config.yaml /var/lib/kube-proxy/",
      "sudo chmod 600 /var/lib/kubelet/*-key.pem /var/lib/kubelet/kubeconfig /var/lib/kube-proxy/kubeconfig",
      "sudo chown root:root /var/lib/kubelet/* /var/lib/kube-proxy/*",

      "wget -q --show-progress --https-only --timestamping \"https://github.com/opencontainers/runc/releases/download/v${var.runc_version}/runc.amd64\"",
      "sudo install -m 755 runc.amd64 ${var.bin_dir}/runc",
      "rm runc.amd64",

      "wget -q --show-progress --https-only --timestamping \"https://github.com/containernetworking/plugins/releases/download/v${var.cni_plugins_version}/cni-plugins-linux-amd64-v${var.cni_plugins_version}.tgz\"",
      "sudo tar xf cni-plugins-linux-amd64-v${var.cni_plugins_version}.tgz -C /opt/cni/bin/",
      "rm cni-plugins-linux-amd64-v${var.cni_plugins_version}.tgz",

      "wget -q --show-progress --https-only --timestamping \"https://github.com/containerd/containerd/releases/download/v${var.containerd_version}/containerd-${var.containerd_version}-linux-amd64.tar.gz\"",
      "sudo tar xf containerd-${var.containerd_version}-linux-amd64.tar.gz -C ${var.bin_dir} --strip-components=1",
      "rm containerd-${var.containerd_version}-linux-amd64.tar.gz",

      "sudo mkdir -p /etc/containerd",
      "cat > /tmp/config.toml << TOML",
      "version = 2",
      "[plugins]",
      "  [plugins.\"io.containerd.grpc.v1.cri\"]",
      "    [plugins.\"io.containerd.grpc.v1.cri\".containerd]",
      "      [plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes]",
      "        [plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runc]",
      "          runtime_type = \"io.containerd.runc.v2\"",
      "          [plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runc.options]",
      "            SystemdCgroup = true",
      "    [plugins.\"io.containerd.grpc.v1.cri\".sandbox]",
      "      image = \"registry.k8s.io/pause:3.9\"",
      "TOML",
      "sudo mv /tmp/config.toml /etc/containerd/config.toml",

      "sudo mv /tmp/containerd.service /etc/systemd/system/",
      "sudo mv /tmp/kubelet.service /etc/systemd/system/",
      "sudo mv /tmp/kube-proxy.service /etc/systemd/system/",

      "wget -q --show-progress --https-only --timestamping \"https://dl.k8s.io/release/v${var.kubernetes_version}/bin/linux/amd64/kubelet\"",
      "wget -q --show-progress --https-only --timestamping \"https://dl.k8s.io/release/v${var.kubernetes_version}/bin/linux/amd64/kube-proxy\"",
      "chmod +x kubelet kube-proxy",
      "sudo mv kubelet kube-proxy ${var.bin_dir}/",

      "cat > /tmp/kubelet-config.yaml << YAML",
      "kind: KubeletConfiguration",
      "apiVersion: kubelet.config.k8s.io/v1beta1",
      "authentication:",
      "  anonymous:",
      "    enabled: false",
      "  webhook:",
      "    enabled: true",
      "  x509:",
      "    clientCAFile: \"/var/lib/kubelet/ca.pem\"",
      "authorization:",
      "  mode: Webhook",
      "clusterDomain: \"${var.dns_domain}\"",
      "clusterDNS:",
      "  - \"${local.dns_service_ip}\"",
      "podCIDR: \"${local.worker_pod_cidrs[each.value.hostname]}\"",
      "resolvConf: \"/run/systemd/resolve/resolv.conf\"",
      "runtimeRequestTimeout: \"15m\"",
      "tlsCertFile: \"/var/lib/kubelet/${each.value.hostname}.pem\"",
      "tlsPrivateKeyFile: \"/var/lib/kubelet/${each.value.hostname}-key.pem\"",
      "YAML",
      "sudo mv /tmp/kubelet-config.yaml /var/lib/kubelet/",

      "cat > /tmp/10-bridge.conf << CNI",
      "{\"cniVersion\":\"0.4.0\",\"name\":\"${var.cluster_name}\",\"type\":\"bridge\",\"bridge\":\"cni0\",\"isGateway\":true,\"ipMasq\":true,\"ipam\":{\"type\":\"host-local\",\"ranges\":[[{\"subnet\":\"${local.worker_pod_cidrs[each.value.hostname]}\"}]],\"routes\":[{\"dst\":\"0.0.0.0/0\"}]}}",
      "CNI",
      "sudo mv /tmp/10-bridge.conf /etc/cni/net.d/",

      "cat > /tmp/99-loopback.conf << CNI",
      "{\"cniVersion\":\"0.4.0\",\"name\":\"lo\",\"type\":\"loopback\"}",
      "CNI",
      "sudo mv /tmp/99-loopback.conf /etc/cni/net.d/",

      "sudo systemctl daemon-reload",
      "sudo systemctl enable containerd kubelet kube-proxy",
      "sudo systemctl start containerd kubelet kube-proxy",
    ]
  }
}

# ============================================================================
# CLUSTER ADDONS (CoreDNS + RBAC)
# ============================================================================
resource "null_resource" "cluster_addons" {
  depends_on = [null_resource.worker]

  triggers = {
    dns_domain     = var.dns_domain
    dns_service_ip = local.dns_service_ip
  }

  connection {
    type        = "ssh"
    host        = var.controllers[0].ip
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    timeout     = "30s"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/kube-apiserver-to-kubelet.yaml.tpl", {})
    destination = "/tmp/kube-apiserver-to-kubelet.yaml"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/coredns.yaml.tpl", {
      dns_domain     = var.dns_domain
      dns_service_ip = local.dns_service_ip
      replicas       = min(length(var.workers), 2)
    })
    destination = "/tmp/coredns.yaml"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/kubeconfig.tpl", {
      ca_cert     = tls_self_signed_cert.ca.cert_pem
      server      = "https://127.0.0.1:6443"
      user        = "admin"
      client_cert = tls_locally_signed_cert.admin.cert_pem
      client_key  = tls_private_key.admin.private_key_pem
    })
    destination = "/tmp/admin.kubeconfig"
  }

  provisioner "remote-exec" {
    inline = [
      "while ! curl -sk --cacert /var/lib/kubernetes/ca.pem https://127.0.0.1:6443/healthz 2>/dev/null | grep -q ok; do echo 'waiting for API server...'; sleep 5; done",

      "mkdir -p ~/.kube",
      "cp /tmp/admin.kubeconfig ~/.kube/config",

      "kubectl apply -f /tmp/kube-apiserver-to-kubelet.yaml",
      "sleep 5",

      "kubectl apply -f /tmp/coredns.yaml",
      "sleep 5",

      "echo '--- Cluster Addons Deployed ---'",
      "kubectl get nodes -o wide",
      "kubectl get pods -n kube-system -o wide",
    ]
  }
}

# ============================================================================
# VERIFICATION
# ============================================================================
resource "null_resource" "verify" {
  depends_on = [null_resource.cluster_addons, null_resource.helm_addons]

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
      "echo '=== BareMetal Kubernetes Cluster Status ==='",
      "echo '--- Nodes ---'",
      "kubectl get nodes -o wide",
      "echo '--- CoreDNS ---'",
      "kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide 2>/dev/null || echo 'coredns not yet running'",
      "echo '--- Control Plane ---'",
      "kubectl -n kube-system get pods 2>/dev/null | head -20 || true",
      "echo '--- Addons ---'",
      "kubectl get ingressclass 2>/dev/null && echo 'traefik: ingress class configured' || echo 'traefik: not configured'",
      "kubectl get crd | grep -i kyverno 2>/dev/null | head -1 && echo 'kyverno: CRDs installed' || echo 'kyverno: not installed'",
      "kubectl get crd | grep -i trivy 2>/dev/null | head -1 && echo 'trivy: CRDs installed' || echo 'trivy: not installed'",
      "echo '=== Cluster is operational ==='",
      "echo 'Admin kubeconfig: ${abspath(local_file.admin_kubeconfig.filename)}'",
    ]
  }
}
