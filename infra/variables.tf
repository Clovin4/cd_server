variable "do_token" {
  type      = string
  sensitive = true
}

variable "ssh_key_fingerprint" {
  type = string
}

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

