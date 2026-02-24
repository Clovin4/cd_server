# ── Remote State Backend ───────────────────────────────────────────────────────
# Uses DigitalOcean Spaces (S3-compatible) to store Terraform state.
#
# The bucket (lazy1-tfstate) must exist before `terraform init` can run.
# The CI workflow handles this automatically with a doctl preflight check.
# To bootstrap manually: doctl spaces create lazy1-tfstate --region nyc3
#
# To reuse this backend in another DO module, copy this file and change `key`.
# All other settings are bucket-level and stay the same across modules.
terraform {
  backend "s3" {
    endpoints = {
      s3 = "https://nyc3.digitaloceanspaces.com"
    }
    bucket = "lazy1-tfstate"
    key    = "kthw/terraform.tfstate"

    # Required by the S3 provider but ignored by DO Spaces
    region = "us-east-1"

    # Skip AWS-specific validation that DO Spaces doesn't support
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}
