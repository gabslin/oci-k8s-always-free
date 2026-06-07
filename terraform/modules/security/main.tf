resource "oci_core_network_security_group" "cluster" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "kube-cluster-nsg"
}

resource "oci_core_network_security_group_security_rule" "ingress_from_user" {
  network_security_group_id = oci_core_network_security_group.cluster.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = var.allowed_source_cidr
  source_type               = "CIDR_BLOCK"
  description               = "Libera todo trafego a partir do IP publico do usuario."
}

resource "oci_core_network_security_group_security_rule" "ingress_from_vcn" {
  network_security_group_id = oci_core_network_security_group.cluster.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "Libera trafego interno entre nodes e IPs privados do MetalLB."
}

resource "oci_core_network_security_group_security_rule" "egress_all" {
  network_security_group_id = oci_core_network_security_group.cluster.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Libera saida para instalacao de pacotes e manifests."
}
