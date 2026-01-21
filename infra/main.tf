terraform {
  required_version = ">= 1.5.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.40"
    }
  }

  backend "s3" {
    endpoints = {
      s3 = "https://nyc3.digitaloceanspaces.com"
    }
    bucket                      = "lazy1-tfstate"
    key                         = "cd-server/terraform.tfstate"
    region                      = "us-east-1" # Required but ignored by DO Spaces
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}


provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_droplet" "vps" {
  name               = var.name
  region             = var.region
  size               = var.size
  image              = var.image
  ssh_keys           = [var.ssh_key_fingerprint]
  monitoring         = true
  backups            = false
  ipv6               = false
  tags               = ["cd", "infra"]
}


output "ip_address" {
  value = digitalocean_droplet.vps.ipv4_address
}

