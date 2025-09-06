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

