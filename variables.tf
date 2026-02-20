# ABOUTME: Input variables for the OCI Always Free ARM instance stack.
# ABOUTME: Compartment ID and region are required; everything else has defaults.

variable "compartment_id" {
  description = "OCID of the compartment (usually your tenancy OCID for Always Free)"
  type        = string
}

variable "region" {
  description = "OCI region identifier (e.g., us-chicago-1, eu-frankfurt-1)"
  type        = string
}

variable "availability_domain_index" {
  description = "Index into the list of availability domains (0-based). Change if your preferred AD is full."
  type        = number
  default     = 0
}

variable "ssh_public_key" {
  description = "SSH public key string. If null, reads from ssh_public_key_path instead."
  type        = string
  default     = null
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file (used when ssh_public_key is null)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "name_prefix" {
  description = "Prefix for resource display names and DNS labels"
  type        = string
  default     = "oci-arm"

  validation {
    condition     = length(replace(lower(var.name_prefix), "/[^a-z0-9]/", "")) + 3 <= 15
    error_message = "name_prefix is too long — the sanitized form plus suffix (e.g., 'vcn') must fit in 15 characters (OCI DNS label limit)."
  }
}

variable "ocpus" {
  description = "Number of ARM OCPUs (Always Free max: 4 total across all instances)"
  type        = number
  default     = 4
}

variable "memory_in_gbs" {
  description = "Memory in GB (Always Free max: 24 total across all instances)"
  type        = number
  default     = 24
}

variable "boot_volume_size_in_gbs" {
  description = "Boot volume size in GB (Always Free max: 200 total across all volumes)"
  type        = number
  default     = 47
}

variable "assign_public_ip" {
  description = "Assign a public IP (disable once you have alternative access, e.g., VPN)"
  type        = bool
  default     = true
}
