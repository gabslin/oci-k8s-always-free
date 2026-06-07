output "cluster_access" {
  description = "Resumo com os acessos principais do cluster."
  value       = <<EOT

Cluster Kubernetes criado com sucesso.

SSH:
  kube   -> ssh -i ${var.ssh_private_key_path} opc@${module.compute.public_ips["kube"]}
  kube02 -> ssh -i ${var.ssh_private_key_path} opc@${module.compute.public_ips["kube02"]}
  kube03 -> ssh -i ${var.ssh_private_key_path} opc@${module.compute.public_ips["kube03"]}
  kube04 -> ssh -i ${var.ssh_private_key_path} opc@${module.compute.public_ips["kube04"]}

ArgoCD:
  URL     -> https://${module.compute.public_ips["kube"]}:30868
  Usuario -> admin
  Senha   -> ssh -i ${var.ssh_private_key_path} opc@${module.compute.public_ips["kube"]} 'kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d; echo'

Kubeconfig:
  scp -i ${var.ssh_private_key_path} opc@${module.compute.public_ips["kube"]}:~/.kube/config ./kubeconfig-oci
  export KUBECONFIG=./kubeconfig-oci

IPs:
  kube   -> publico ${module.compute.public_ips["kube"]} | privado ${module.compute.private_ips["kube"]}
  kube02 -> publico ${module.compute.public_ips["kube02"]} | privado ${module.compute.private_ips["kube02"]}
  kube03 -> publico ${module.compute.public_ips["kube03"]} | privado ${module.compute.private_ips["kube03"]}
  kube04 -> publico ${module.compute.public_ips["kube04"]} | privado ${module.compute.private_ips["kube04"]}

Rede liberada:
  ${local.allowed_source_cidr}

EOT
}
