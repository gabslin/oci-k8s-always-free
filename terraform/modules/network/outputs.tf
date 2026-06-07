output "vcn_id" {
  value = oci_core_vcn.kube.id
}

output "subnet_id" {
  value = oci_core_subnet.public.id
}
