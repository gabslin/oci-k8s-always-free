output "allowed_source_cidr" {
  description = "CIDR liberado nas regras de entrada."
  value       = local.allowed_source_cidr
}

output "public_ips" {
  description = "IPs publicos dos nodes."
  value       = module.compute.public_ips
}

output "private_ips" {
  description = "IPs privados dos nodes."
  value       = module.compute.private_ips
}

output "ssh_commands" {
  description = "Comandos SSH para acessar os nodes."
  value = {
    for name, ip in module.compute.public_ips :
    name => "ssh -i ${var.ssh_private_key_path} opc@${ip}"
  }
}

output "ssh_kube" {
  description = "Comando SSH para acessar o control-plane."
  value       = "ssh -i ${var.ssh_private_key_path} opc@${module.compute.public_ips["kube"]}"
}

output "ssh_kube02" {
  description = "Comando SSH para acessar o worker kube02."
  value       = "ssh -i ${var.ssh_private_key_path} opc@${module.compute.public_ips["kube02"]}"
}

output "ssh_kube03" {
  description = "Comando SSH para acessar o worker kube03."
  value       = "ssh -i ${var.ssh_private_key_path} opc@${module.compute.public_ips["kube03"]}"
}

output "ssh_kube04" {
  description = "Comando SSH para acessar o worker kube04."
  value       = "ssh -i ${var.ssh_private_key_path} opc@${module.compute.public_ips["kube04"]}"
}

output "argocd_temporary_endpoint" {
  description = "Endpoint temporario do ArgoCD via NodePort HTTPS no IP publico do control-plane."
  value       = "https://${module.compute.public_ips["kube"]}:30868"
}

output "kubectl_config_command" {
  description = "Comando para copiar o kubeconfig do control-plane para a maquina local."
  value       = "scp -i ${var.ssh_private_key_path} opc@${module.compute.public_ips["kube"]}:~/.kube/config ./kubeconfig-oci"
}
