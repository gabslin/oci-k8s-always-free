output "instance_ids" {
  value = {
    for name, instance in oci_core_instance.node :
    name => instance.id
  }
}

output "public_ips" {
  value = {
    for name, instance in oci_core_instance.node :
    name => instance.public_ip
  }
}

output "private_ips" {
  value = {
    for name, instance in oci_core_instance.node :
    name => instance.private_ip
  }
}
