terraform {
  required_version = ">= 1.5.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.40"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# ── VPC ────────────────────────────────────────────────────────────────────────
resource "digitalocean_vpc" "main" {
  name     = var.vpc_name
  region   = var.region
  ip_range = var.vpc_ip_range
}

# ── Test VMs ───────────────────────────────────────────────────────────────────
# Add / remove entries in var.vms to spin VMs up or down.
resource "digitalocean_droplet" "vm" {
  for_each = var.vms

  name     = each.key
  region   = var.region
  size     = each.value.size
  image    = each.value.image
  vpc_uuid = digitalocean_vpc.main.id
  ssh_keys = [var.ssh_key_fingerprint]

  monitoring = true
  backups    = false
  ipv6       = false

  tags = concat(["test", "vpc"], each.value.tags)
}
