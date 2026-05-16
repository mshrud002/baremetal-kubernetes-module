[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=${bin_dir}/kube-apiserver \
  --advertise-address=${advertise_address} \
  --allow-privileged=true \
  --apiserver-count=${apiserver_count} \
  --audit-log-maxage=30 \
  --audit-log-maxbackup=3 \
  --audit-log-maxsize=100 \
  --audit-log-path=/var/log/audit.log \
  --authorization-mode=Node,RBAC \
  --bind-address=0.0.0.0 \
  --client-ca-file=${kubernetes_config_dir}/ca.pem \
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \
  --etcd-cafile=${kubernetes_config_dir}/ca.pem \
  --etcd-certfile=${kubernetes_config_dir}/kubernetes.pem \
  --etcd-keyfile=${kubernetes_config_dir}/kubernetes-key.pem \
  --etcd-servers=${etcd_servers} \
  --event-ttl=1h \
  --encryption-provider-config=${kubernetes_config_dir}/encryption-config.yaml \
  --kubelet-certificate-authority=${kubernetes_config_dir}/ca.pem \
  --kubelet-client-certificate=${kubernetes_config_dir}/kubernetes.pem \
  --kubelet-client-key=${kubernetes_config_dir}/kubernetes-key.pem \
  --kubelet-https=true \
  --runtime-config='api/all=true' \
  --service-account-issuer=https://${kubernetes_service_ip}:6443 \
  --service-account-key-file=${kubernetes_config_dir}/service-account.pub \
  --service-account-signing-key-file=${kubernetes_config_dir}/service-account-key.pem \
  --service-cluster-ip-range=${service_cidr} \
  --service-node-port-range=30000-32767 \
  --tls-cert-file=${kubernetes_config_dir}/kubernetes.pem \
  --tls-private-key-file=${kubernetes_config_dir}/kubernetes-key.pem \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
