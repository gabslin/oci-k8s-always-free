data "http" "current_public_ip" {
  count = var.allowed_source_cidr == null ? 1 : 0

  url = "https://api.ipify.org"
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

data "oci_core_images" "oracle_linux" {
  count = var.image_ocid == "" ? 1 : 0

  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = var.operating_system_version
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  allowed_source_cidr = var.allowed_source_cidr != null ? var.allowed_source_cidr : "${chomp(data.http.current_public_ip[0].response_body)}/32"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  image_id            = var.image_ocid != "" ? var.image_ocid : data.oci_core_images.oracle_linux[0].images[0].id

  nodes = {
    kube = {
      role          = "control-plane"
      private_ip    = var.node_private_ips["kube"]
      ocpus         = var.control_plane_ocpus
      memory_in_gbs = var.control_plane_memory_in_gbs
    }
    kube02 = {
      role          = "worker"
      private_ip    = var.node_private_ips["kube02"]
      ocpus         = var.ocpus
      memory_in_gbs = var.memory_in_gbs
    }
    kube03 = {
      role          = "worker"
      private_ip    = var.node_private_ips["kube03"]
      ocpus         = var.ocpus
      memory_in_gbs = var.memory_in_gbs
    }
    kube04 = {
      role          = "worker"
      private_ip    = var.node_private_ips["kube04"]
      ocpus         = var.ocpus
      memory_in_gbs = var.memory_in_gbs
    }
  }
}

module "network" {
  source = "./modules/network"

  compartment_ocid = var.compartment_ocid
  vcn_cidr         = var.vcn_cidr
  subnet_cidr      = var.subnet_cidr
}

module "security" {
  source = "./modules/security"

  compartment_ocid    = var.compartment_ocid
  vcn_id              = module.network.vcn_id
  vcn_cidr            = var.vcn_cidr
  allowed_source_cidr = local.allowed_source_cidr
}

module "compute" {
  source = "./modules/compute"

  compartment_ocid    = var.compartment_ocid
  availability_domain = local.availability_domain
  subnet_id           = module.network.subnet_id
  nsg_ids             = [module.security.cluster_nsg_id]
  ssh_public_key      = var.ssh_public_key
  shape               = var.shape
  image_id            = local.image_id
  nodes               = local.nodes
}

resource "null_resource" "bootstrap_kubernetes" {
  depends_on = [module.compute]

  triggers = {
    control_plane_id = module.compute.instance_ids["kube"]
    worker_ids       = join(",", [for name in ["kube02", "kube03", "kube04"] : module.compute.instance_ids[name]])
    script_hash      = filesha256("${path.module}/../scripts/terraform-bootstrap.sh")
    common_hash      = filesha256("${path.module}/../scripts/00-common.sh")
    containerd_hash  = filesha256("${path.module}/../scripts/01-containerd.sh")
    kubernetes_hash  = filesha256("${path.module}/../scripts/02-kubernetes.sh")
    control_hash     = filesha256("${path.module}/../scripts/03-control-plane.sh")
    worker_hash      = filesha256("${path.module}/../scripts/04-worker.sh")
    addons_hash      = filesha256("${path.module}/../scripts/05-addons.sh")
    packages_hash    = filesha256("${path.module}/../scripts/lib-packages.sh")
  }

  provisioner "local-exec" {
    command     = "bash ${path.module}/../scripts/terraform-bootstrap.sh"
    interpreter = ["/bin/bash", "-c"]

    environment = {
      SSH_PRIVATE_KEY          = pathexpand(var.ssh_private_key_path)
      CONTROL_PLANE_PUBLIC_IP  = module.compute.public_ips["kube"]
      CONTROL_PLANE_PRIVATE_IP = module.compute.private_ips["kube"]
      WORKER_NAMES             = "kube02 kube03 kube04"
      WORKER_PUBLIC_IPS        = join(" ", [for name in ["kube02", "kube03", "kube04"] : module.compute.public_ips[name]])
      NODE_HOSTS               = join(",", [for name in ["kube", "kube02", "kube03", "kube04"] : "${module.compute.private_ips[name]}:${name}"])
      METALLB_POOL             = var.metallb_pool
    }
  }
}
