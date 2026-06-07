variable "compartment_ocid" {
  type      = string
  sensitive = true
}

variable "availability_domain" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "nsg_ids" {
  type = list(string)
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
}

variable "shape" {
  type = string
}

variable "image_id" {
  type = string
}

variable "nodes" {
  type = map(object({
    role          = string
    private_ip    = string
    ocpus         = number
    memory_in_gbs = number
  }))
}
