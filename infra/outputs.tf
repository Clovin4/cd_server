output "droplet_ip" {
  description = "Public IPv4 address of Dokploy server"
  value       = digitalocean_droplet.vps.ipv4_address
}
