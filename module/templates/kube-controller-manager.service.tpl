[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=${bin_dir}/kube-controller-manager \
  --bind-address=0.0.0.0 \
  --cluster-cidr=${pod_cidr} \
  --cluster-name=${cluster_name} \
  --cluster-signing-cert-file=${kubernetes_config_dir}/ca.pem \
  --cluster-signing-key-file=${kubernetes_config_dir}/ca-key.pem \
  --kubeconfig=${kubernetes_config_dir}/kube-controller-manager.kubeconfig \
  --leader-elect=true \
  --root-ca-file=${kubernetes_config_dir}/ca.pem \
  --service-account-private-key-file=${kubernetes_config_dir}/service-account-key.pem \
  --service-cluster-ip-range=${service_cidr} \
  --use-service-account-credentials=true \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
