# Hetzner private network for cluster communication

resource "hcloud_network" "cluster" {
  name     = "${var.cluster_name}-network"
  ip_range = var.private_network_subnet
}

resource "hcloud_network_subnet" "cluster" {
  network_id   = hcloud_network.cluster.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = var.private_network_subnet
}

# SSH keys for server access
resource "hcloud_ssh_key" "cluster" {
  for_each = { for idx, key in var.ssh_public_keys : idx => key }

  name       = "${var.cluster_name}-key-${each.key}"
  public_key = each.value
}
