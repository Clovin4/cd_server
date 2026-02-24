output "vpc_id" {
  description = "ID of the VPC"
  value       = digitalocean_vpc.main.id
}

output "vpc_ip_range" {
  description = "CIDR block assigned to the VPC"
  value       = digitalocean_vpc.main.ip_range
}

output "vm_ips" {
  description = "Map of VM name → public IPv4 address"
  value       = { for name, vm in digitalocean_droplet.vm : name => vm.ipv4_address }
}

output "vm_private_ips" {
  description = "Map of VM name → private IPv4 address (within the VPC)"
  value       = { for name, vm in digitalocean_droplet.vm : name => vm.ipv4_address_private }
}

# ── KtHW helpers ──────────────────────────────────────────────────────────────
# Kubernetes the Hard Way requires hostname resolution across all nodes.
# Paste this block into /etc/hosts on each machine (or use the Ansible setup playbook).
output "hosts_file_entries" {
  description = "Ready-to-paste /etc/hosts block for all KtHW nodes (private IPs)"
  value = join("\n", concat(
    ["# Kubernetes the Hard Way"],
    [for name, vm in digitalocean_droplet.vm : "${vm.ipv4_address_private}\t${name}"]
  ))
}

# SSH config block — paste into ~/.ssh/config on your local machine to access
# all nodes by name through the jumpbox.
output "ssh_config" {
  description = "~/.ssh/config block for accessing all nodes via jumpbox"
  value = join("\n", flatten([
    [
      "# KtHW — direct jumpbox access",
      "Host jumpbox",
      "  HostName ${digitalocean_droplet.vm["jumpbox"].ipv4_address}",
      "  User root",
      "  IdentityFile ~/.ssh/id_rsa",
      "",
    ],
    [
      for name, vm in digitalocean_droplet.vm : join("\n", [
        "Host ${name}",
        "  HostName ${vm.ipv4_address_private}",
        "  User root",
        "  IdentityFile ~/.ssh/id_rsa",
        "  ProxyJump jumpbox",
        "",
      ]) if name != "jumpbox"
    ]
  ]))
}

