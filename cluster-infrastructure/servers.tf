data "hcloud_datacenters" "ds" {}

locals {
  # Filter datacenters by location (var.datacenter e.g. "nbg1")
  valid_datacenters = [
    for dc in data.hcloud_datacenters.ds.datacenters : dc.name
    if dc.location.name == var.datacenter
  ]
  # Pick the first one to ensure all resources are in the same datacenter
  primary_ip_datacenter = local.valid_datacenters[0]

  # T015: Identify nodes by role
  load_balancer_nodes = {
    for name, node in var.nodes : name => node
    if contains(node.roles, "load_balancer")
  }

  control_plane_nodes = {
    for name, node in var.nodes : name => node
    if contains(node.roles, "control_plane")
  }

  # T047: Worker role detection
  worker_nodes = {
    for name, node in var.nodes : name => node
    if contains(node.roles, "worker") && !contains(node.roles, "control_plane")
  }

  # Assign IPs deterministically to avoid cycle between server user_data and network attachment
  sorted_nodes = sort(keys(var.nodes))
  node_ips = {
    for idx, name in local.sorted_nodes :
    name => cidrhost(var.private_network_subnet, idx + 10)
  }

  # TODO: Implement cert-manager integration
  cert_manager_helmchart_file = ""
  letsencrypt_clusterissuer_file = ""
}

# Create Primary IPs for all nodes to break dependency cycle
resource "hcloud_primary_ip" "nodes" {
  for_each = var.nodes

  name          = "${var.cluster_name}-${each.key}"
  datacenter    = local.primary_ip_datacenter
  type          = "ipv4"
  assignee_type = "server"
  auto_delete   = false
  labels = {
    cluster = var.cluster_name
    role    = join("-", each.value.roles)
    env     = var.env
  }
}

# Longhorn storage volumes for control plane nodes
resource "hcloud_volume" "longhorn_storage" {
  for_each = local.control_plane_nodes

  name      = "${var.cluster_name}-${each.key}-longhorn"
  size      = var.longhorn_volume_size
  location  = var.datacenter
  format    = "ext4"

  labels = {
    cluster = var.cluster_name
    role    = "longhorn-storage"
    node    = each.key
    env     = var.env
  }
}

# T013: Create Hetzner server resources
resource "hcloud_server" "nodes" {
  depends_on = [null_resource.db_reset]
  for_each   = var.nodes

  name = "${var.cluster_name}-${each.key}"
  # T016: Server configuration
  server_type = each.value.server_type
  image       = "ubuntu-22.04"
  location    = var.datacenter

  # T018: SSH key reference
  ssh_keys = [for k in hcloud_ssh_key.cluster : k.id]

  # T017: IPv4 and IPv6 public address allocation
  public_net {
    ipv4_enabled = true
    ipv4         = hcloud_primary_ip.nodes[each.key].id
    ipv6_enabled = true
  }

  labels = {
    cluster = var.cluster_name
    role    = join("-", each.value.roles)
    env     = var.env
  }

  # T029: Load balancer user_data
  # T045: Control plane user_data
  # T053: Worker-only user_data
  user_data = contains(each.value.roles, "load_balancer") ? templatefile("${path.module}/cloud-init/load-balancer.yaml.tpl", {
    control_plane_ips = [
      for name, node in local.control_plane_nodes :
      local.node_ips[name]
    ]
    }) : (
    contains(each.value.roles, "control_plane") ? templatefile("${path.module}/cloud-init/control-plane.yaml.tpl", {
      hostname                    = "${var.cluster_name}-${each.key}"
      aws_region                  = var.aws_region
      aws_access_key_id          = aws_iam_access_key.k3s_node.id
      aws_secret_access_key       = aws_iam_access_key.k3s_node.secret
      db_connection_ssm_path      = var.ssm_parameter_path
      hcloud_token_ssm_path       = var.hcloud_token_ssm_path
      cluster_token               = random_password.k3s_token.result
      k3s_version                 = var.k3s_version
      load_balancer_ip            = hcloud_primary_ip.nodes[keys(local.load_balancer_nodes)[0]].ip_address
      private_ip                  = local.node_ips[each.key]
      has_worker_role             = contains(each.value.roles, "worker")
      cert_manager_helmchart_file = local.cert_manager_helmchart_file
      letsencrypt_clusterissuer_file = local.letsencrypt_clusterissuer_file
      }) : (
      contains(each.value.roles, "worker") ? templatefile("${path.module}/cloud-init/worker.yaml.tpl", {
        hostname         = "${var.cluster_name}-${each.key}"
        cluster_token    = random_password.k3s_token.result
        k3s_version      = var.k3s_version
        load_balancer_ip = hcloud_primary_ip.nodes[keys(local.load_balancer_nodes)[0]].ip_address
        private_ip       = local.node_ips[each.key]
      }) : null
    )
  )
}

# T014: Create Hetzner server network attachments
resource "hcloud_server_network" "nodes" {
  for_each = var.nodes

  server_id  = hcloud_server.nodes[each.key].id
  network_id = hcloud_network.cluster.id
  ip         = local.node_ips[each.key]
}

# Attach Longhorn storage volumes to control plane nodes
resource "hcloud_volume_attachment" "longhorn_storage" {
  for_each = local.control_plane_nodes

  volume_id = hcloud_volume.longhorn_storage[each.key].id
  server_id = hcloud_server.nodes[each.key].id
  automount = false  # We'll mount it manually via cloud-init to /var/lib/longhorn
}

# Reset database when cluster token changes to prevent "bootstrap data already found" error
resource "null_resource" "db_reset" {
  triggers = {
    token = random_password.k3s_token.result
  }

  provisioner "local-exec" {
    command = <<EOT
      DB_CONN=$(aws ssm get-parameter --name "${var.ssm_parameter_path}" --with-decryption --query "Parameter.Value" --output text)
      psql "$DB_CONN" -c "DROP TABLE IF EXISTS kine;"
    EOT
  }
}
