terraform {
  required_version = ">= 1.5.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.40" # or omit to get latest
    }
  }
}


provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_ssh_key" "gha" {
  name       = "gha-${terraform.workspace}"
  public_key = var.ssh_public_key
}

resource "digitalocean_droplet" "vps" {
  name               = var.name
  region             = var.region
  size               = var.size
  image              = var.image
  ssh_keys           = [var.ssh_key_fingerprint, digitalocean_ssh_key.gha.id]
  monitoring         = true
  backups            = false
  ipv6               = false
  tags               = ["cd", "infra"]
}


output "ip_address" {
  value = digitalocean_droplet.vps.ipv4_address
}

