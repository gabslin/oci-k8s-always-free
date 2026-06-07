variable "compartment_ocid" {
  type      = string
  sensitive = true
}

variable "vcn_cidr" {
  type = string
}

variable "subnet_cidr" {
  type = string
}
