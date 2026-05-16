apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
clusterCIDR: ${cluster_cidr}
clientConnection:
  kubeconfig: "${kubeconfig_path}"
mode: ""
