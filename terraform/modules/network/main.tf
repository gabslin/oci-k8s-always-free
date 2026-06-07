resource "oci_core_vcn" "kube" {
  compartment_id = var.compartment_ocid
  cidr_block     = var.vcn_cidr
  display_name   = "Kube-VCN"
  dns_label      = "kubevcn"
}

resource "oci_core_internet_gateway" "kube" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.kube.id
  display_name   = "GI-Kube-VCN"
  enabled        = true
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.kube.id
  display_name   = "Kube-Public-RT"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.kube.id
  }
}

resource "oci_core_security_list" "subnet" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.kube.id
  display_name   = "Kube-Public-SL"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }
}

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.kube.id
  cidr_block                 = var.subnet_cidr
  display_name               = "VCN-Public"
  dns_label                  = "public"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.subnet.id]
}
