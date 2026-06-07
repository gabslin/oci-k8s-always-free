variable "compartment_ocid" {
  type      = string
  sensitive = true
}

variable "vcn_id" {
  type = string
}

variable "vcn_cidr" {
  type = string
}

variable "allowed_source_cidr" {
  type = string
}
