variable "do_token" {
  type      = string
  sensitive = true
}

variable "ssh_key_fingerprint" {
  type        = string
  description = "Fingerprint of the SSH key registered in DigitalOcean"
}

variable "region" {
  type    = string
  default = "nyc3"
}

# ── VPC ────────────────────────────────────────────────────────────────────────
variable "vpc_name" {
  type    = string
  default = "kthw-vpc"
}

variable "vpc_ip_range" {
  type        = string
  default     = "10.10.0.0/24"
  description = "Private CIDR block for the VPC. Must not overlap existing VPCs in the region."
}

# ── VMs ────────────────────────────────────────────────────────────────────────
# Machine layout matches the Kubernetes the Hard Way prerequisites exactly:
# https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/01-prerequisites.md
#
# Name      Role                  CPU   RAM     Disk   DO Slug              $/mo
# jumpbox   Admin / bastion       1     512MB   10GB   s-1vcpu-512mb-10gb   $4
# server    Control plane         1     2GB     20GB+  s-1vcpu-2gb          $12
# node-0    Worker                1     2GB     20GB+  s-1vcpu-2gb          $12
# node-1    Worker                1     2GB     20GB+  s-1vcpu-2gb          $12
#
# Note: DO's s-1vcpu-2gb ships with 50GB disk, which exceeds the 20GB requirement.
# Total while running: ~$40/mo. Destroy when not studying to avoid charges.
variable "vms" {
  type = map(object({
    size  = string
    image = string
    tags  = list(string)
  }))
  default = {
    "jumpbox" = {
      size  = "s-1vcpu-512mb-10gb"
      image = "debian-12-x64"
      tags  = ["kthw", "admin"]
    }
    "server" = {
      size  = "s-1vcpu-2gb"
      image = "debian-12-x64"
      tags  = ["kthw", "control-plane"]
    }
    "node-0" = {
      size  = "s-1vcpu-2gb"
      image = "debian-12-x64"
      tags  = ["kthw", "worker"]
    }
    "node-1" = {
      size  = "s-1vcpu-2gb"
      image = "debian-12-x64"
      tags  = ["kthw", "worker"]
    }
  }
}
