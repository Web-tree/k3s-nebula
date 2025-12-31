terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.52"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# AWS provider for SSM Parameter Store access
provider "aws" {
  region = var.aws_region
}

# Retrieve Hetzner Cloud API token from AWS SSM Parameter Store
data "aws_ssm_parameter" "hcloud_token" {
  name = var.hcloud_token_ssm_path
}

# Retrieve PostgreSQL connection string from AWS SSM Parameter Store
data "aws_ssm_parameter" "postgres_connection" {
  name            = var.ssm_parameter_path
  with_decryption = true
}

# Hetzner Cloud provider configured with token from SSM
provider "hcloud" {
  token = data.aws_ssm_parameter.hcloud_token.value
}
