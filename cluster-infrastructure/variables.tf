# Input variables for HA k3s cluster on Hetzner Cloud

variable "env" {
  description = "Environment name (prod, staging, dev)"
  type        = string

  validation {
    condition     = can(regex("^(prod|staging|dev)$", var.env))
    error_message = "Environment must be one of: prod, staging, dev."
  }
}

variable "ssh_public_keys" {
  description = "List of SSH public keys for server access"
  type        = list(string)

  validation {
    condition     = length(var.ssh_public_keys) > 0
    error_message = "At least one SSH public key must be provided."
  }
}

variable "nodes" {
  description = "Map of node configurations with server type and roles"
  type = map(object({
    server_type = string
    roles       = list(string)
  }))

  validation {
    condition = alltrue([
      for name, node in var.nodes :
      contains(["cx21", "cx22", "cx31", "cx32", "cx41", "cx42", "cx51", "cx52"], node.server_type)
    ])
    error_message = "Server type must be a valid Hetzner Cloud server type."
  }

  validation {
    condition = alltrue([
      for name, node in var.nodes :
      length(node.roles) > 0
    ])
    error_message = "Each node must have at least one role."
  }

  validation {
    condition = alltrue([
      for name, node in var.nodes :
      alltrue([for role in node.roles : contains(["control_plane", "worker", "load_balancer"], role)])
    ])
    error_message = "Node roles must be one of: control_plane, worker, load_balancer."
  }

  # HA requirement: at least 2 control plane nodes
  validation {
    condition = length([
      for name, node in var.nodes :
      name if contains(node.roles, "control_plane")
    ]) >= 2
    error_message = "High availability requires at least 2 control plane nodes."
  }

  # HA requirement: exactly 1 load balancer
  validation {
    condition = length([
      for name, node in var.nodes :
      name if contains(node.roles, "load_balancer")
    ]) == 1
    error_message = "Exactly 1 load balancer node is required."
  }
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "k3s-ha"
}

variable "datacenter" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "nbg1"
}

variable "k3s_version" {
  description = "k3s version to install"
  type        = string
  default     = "v1.28.3+k3s1"
}

variable "ssm_parameter_path" {
  description = "AWS SSM parameter path for PostgreSQL connection string"
  type        = string

  validation {
    condition     = can(regex("^/", var.ssm_parameter_path))
    error_message = "ssm_parameter_path must start with /."
  }
}

variable "hcloud_token_ssm_path" {
  description = "AWS SSM parameter path for Hetzner Cloud API token"
  type        = string

  validation {
    condition     = can(regex("^/", var.hcloud_token_ssm_path))
    error_message = "hcloud_token_ssm_path must start with /."
  }
}

variable "private_network_subnet" {
  description = "Private network subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "aws_region" {
  description = "AWS region for SSM parameter store"
  type        = string
  default     = "eu-central-1"
}

variable "cert_manager_enabled" {
  description = "Enable cert-manager installation during cluster initialization"
  type        = bool
  default     = true
}

variable "cert_manager_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "v1.19.1"
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt certificate notifications"
  type        = string
  default     = ""
}

variable "letsencrypt_enabled" {
  description = "Enable Let's Encrypt ClusterIssuer creation"
  type        = bool
  default     = false
}

variable "longhorn_volume_size" {
  description = "Size of Longhorn storage volume in GB for each control plane node"
  type        = number
  default     = 10

  validation {
    condition     = var.longhorn_volume_size >= 10 && var.longhorn_volume_size <= 10000
    error_message = "Longhorn volume size must be between 10 GB and 10000 GB."
  }
}
