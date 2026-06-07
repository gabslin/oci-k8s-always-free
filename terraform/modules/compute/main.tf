resource "oci_core_instance" "node" {
  for_each = var.nodes

  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = each.key
  shape               = var.shape

  shape_config {
    ocpus         = each.value.ocpus
    memory_in_gbs = each.value.memory_in_gbs
  }

  create_vnic_details {
    assign_private_dns_record = true
    assign_public_ip          = true
    display_name              = "${each.key}-vnic"
    hostname_label            = each.key
    nsg_ids                   = var.nsg_ids
    private_ip                = each.value.private_ip
    subnet_id                 = var.subnet_id
  }

  source_details {
    source_id   = var.image_id
    source_type = "image"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
      hostname   = each.key
      node_hosts = var.nodes
    }))
  }

  agent_config {
    is_management_disabled = false
    is_monitoring_disabled = false

    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }

    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Run Command"
    }
  }

  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  availability_config {
    recovery_action = "RESTORE_INSTANCE"
  }
}
