variable "region" {
  description = "Regiao OCI onde o cluster sera criado."
  type        = string
}

variable "tenancy_ocid" {
  description = "OCID da tenancy OCI. Opcional quando o provider usa ~/.oci/config ou variaveis de ambiente."
  type        = string
  default     = null
  sensitive   = true
}

variable "user_ocid" {
  description = "OCID do usuario OCI. Opcional quando o provider usa ~/.oci/config ou variaveis de ambiente."
  type        = string
  default     = null
  sensitive   = true
}

variable "fingerprint" {
  description = "Fingerprint da API key OCI. Opcional quando o provider usa ~/.oci/config ou variaveis de ambiente."
  type        = string
  default     = null
  sensitive   = true
}

variable "oci_private_key_path" {
  description = "Caminho local da chave privada da API OCI. Opcional quando o provider usa ~/.oci/config ou variaveis de ambiente."
  type        = string
  default     = null
  sensitive   = true
}

variable "oci_private_key" {
  description = "Conteudo da chave privada da API OCI. Prefira oci_private_key_path."
  type        = string
  default     = null
  sensitive   = true
}

variable "compartment_ocid" {
  description = "OCID do compartment onde os recursos serao criados."
  type        = string
  sensitive   = true
}

variable "allowed_source_cidr" {
  description = "CIDR autorizado a acessar as instancias. Se null, o Terraform detecta o IP publico atual e usa /32."
  type        = string
  default     = null
}

variable "ssh_public_key" {
  description = "Chave publica SSH usada em todas as instancias."
  type        = string
  sensitive   = true
}

variable "ssh_private_key_path" {
  description = "Caminho local da chave privada correspondente, usada pelo bootstrap via SSH."
  type        = string
  default     = "~/.ssh/kube.key"
}

variable "vcn_cidr" {
  description = "CIDR da VCN."
  type        = string
  default     = "10.0.0.0/24"
}

variable "subnet_cidr" {
  description = "CIDR da subnet publica."
  type        = string
  default     = "10.0.0.0/24"
}

variable "metallb_pool" {
  description = "Pool privado usado pelo MetalLB."
  type        = string
  default     = "10.0.0.240-10.0.0.250"
}

variable "shape" {
  description = "Shape OCI das instancias."
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "ocpus" {
  description = "OCPUs por instancia."
  type        = number
  default     = 1
}

variable "memory_in_gbs" {
  description = "Memoria em GB por instancia."
  type        = number
  default     = 6
}

variable "control_plane_ocpus" {
  description = "OCPUs do control-plane. Use 2 se houver cota; com 1 o bootstrap usa ignore preflight NumCPU."
  type        = number
  default     = 1
}

variable "control_plane_memory_in_gbs" {
  description = "Memoria em GB do control-plane."
  type        = number
  default     = 6
}

variable "operating_system_version" {
  description = "Versao do Oracle Linux ARM64."
  type        = string
  default     = "9"
}

variable "image_ocid" {
  description = "OCID opcional da imagem Oracle Linux 9 ARM64. Se vazio, o Terraform usa a imagem mais recente compativel com o shape."
  type        = string
  default     = ""
}

variable "node_private_ips" {
  description = "IPs privados fixos dos nodes."
  type        = map(string)
  default = {
    kube   = "10.0.0.39"
    kube02 = "10.0.0.135"
    kube03 = "10.0.0.74"
    kube04 = "10.0.0.118"
  }
}
