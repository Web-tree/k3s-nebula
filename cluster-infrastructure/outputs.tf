# T019: Output values

output "cluster_endpoint" {
  description = "Public endpoint for the Kubernetes cluster"
  value       = "https://${hcloud_server.nodes[keys(local.load_balancer_nodes)[0]].ipv4_address}:6443"
}

output "load_balancer_ip" {
  description = "Load balancer public IP address"
  value       = hcloud_server.nodes[keys(local.load_balancer_nodes)[0]].ipv4_address
}

output "load_balancer" {
  description = "Load balancer node information"
  value = {
    name = hcloud_server.nodes[keys(local.load_balancer_nodes)[0]].name
    ipv4 = hcloud_server.nodes[keys(local.load_balancer_nodes)[0]].ipv4_address
    ipv6 = hcloud_server.nodes[keys(local.load_balancer_nodes)[0]].ipv6_address
  }
}

output "control_plane_nodes" {
  description = "Control plane nodes information"
  value = [
    for name, node in local.control_plane_nodes : {
      name       = hcloud_server.nodes[name].name
      ipv4       = hcloud_server.nodes[name].ipv4_address
      ipv6       = hcloud_server.nodes[name].ipv6_address
      private_ip = local.node_ips[name]
    }
  ]
}

output "worker_nodes" {
  description = "Worker nodes information"
  value = [
    for name, node in local.worker_nodes : {
      name       = hcloud_server.nodes[name].name
      ipv4       = hcloud_server.nodes[name].ipv4_address
      ipv6       = hcloud_server.nodes[name].ipv6_address
      private_ip = local.node_ips[name]
    }
  ]
}

output "all_nodes" {
  description = "All nodes information"
  value = {
    for name, node in var.nodes : name => {
      name = hcloud_server.nodes[name].name
      ipv4 = hcloud_server.nodes[name].ipv4_address
      ipv6 = hcloud_server.nodes[name].ipv6_address
    }
  }
}

output "kubeconfig_command" {
  description = "Command to retrieve kubeconfig"
  value       = "ssh root@${hcloud_server.nodes[keys(local.control_plane_nodes)[0]].ipv4_address} 'cat /etc/rancher/k3s/k3s.yaml' | sed 's/127.0.0.1/${hcloud_server.nodes[keys(local.load_balancer_nodes)[0]].ipv4_address}/g' > kubeconfig.yaml"
}

output "private_network_id" {
  description = "ID of the private network"
  value       = hcloud_network.cluster.id
}

output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = var.cluster_name
}

output "environment" {
  description = "Deployment environment"
  value       = var.env
}
