apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${base64encode(ca_cert)}
    server: ${server}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: ${user}
  name: ${user}@kubernetes
current-context: ${user}@kubernetes
users:
- name: ${user}
  user:
    client-certificate-data: ${base64encode(client_cert)}
    client-key-data: ${base64encode(client_key)}
