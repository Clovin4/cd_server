# Variables for DigitalOcean Droplet
variable "do_token" {
  type      = string
  sensitive = true
}

# SSH key fingerprint for accessing the droplet
variable "ssh_key_fingerprint" {
  type = string
}

# Droplet configuration variables with defaults
variable "name" {
  type    = string
  default = "cd-host"
}

variable "region" {
  type    = string
  default = "nyc3"
}

variable "size" {
  type    = string
  default = "s-1vcpu-1gb"
}

variable "image" {
  type    = string
  default = "ubuntu-22-04-x64"
}

# Ephemeral SSH key pair for CI/CD access
variable "ssh_public_key" {
  description = "Ephemeral public key from CI"
  type        = string
}
