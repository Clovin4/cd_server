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
  tags               = ["dokploy", "infra"]
}

output "ip_address" {
  value = digitalocean_droplet.vps.ipv4_address
}

