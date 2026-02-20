<!-- ABOUTME: README for the OCI Always Free ARM Terraform stack. -->
<!-- ABOUTME: Covers quick start, configuration, free-tier limits, and teardown. -->

# oci-alwaysfree-tf-stack

Terraform stack that provisions an Always Free ARM instance on Oracle Cloud, with VCN, subnet, and internet gateway. Auto-discovers the availability domain and latest Ubuntu 24.04 image so you don't need to look up region-specific OCIDs.

---

## Quick Start

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set compartment_id and region
terraform init
terraform apply
```

---

## Prerequisites

- OCI CLI configured (`oci setup config`) or equivalent environment variables
- Terraform >= 1.0 (or OpenTofu)
- A Pay-as-you-Go OCI account (Always Free resources won't incur charges, but the upgrade from the trial is required for ARM instances to persist)

---

## File Structure

```
oci-alwaysfree-tf-stack/
├── main.tf                  # Provider, data sources, networking, compute
├── variables.tf             # Input variables (2 required, 8 with defaults)
├── outputs.tf               # IPs, OCIDs for downstream use
├── terraform.tfvars.example # Copy to terraform.tfvars and fill in
└── .gitignore               # Ignores tfstate, .terraform/, and tfvars
```

---

## Configuration

Only `compartment_id` and `region` are required. Everything else has sensible defaults.

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `compartment_id` | `string` | *required* | OCID of the compartment (usually your tenancy OCID) |
| `region` | `string` | *required* | OCI region identifier (e.g., `us-chicago-1`) |
| `availability_domain_index` | `number` | `0` | Index into the AD list. Change if your preferred AD is full. |
| `ssh_public_key` | `string` | `null` | SSH public key string. If null, reads from `ssh_public_key_path`. |
| `ssh_public_key_path` | `string` | `~/.ssh/id_ed25519.pub` | Path to SSH public key file (used when `ssh_public_key` is null) |
| `name_prefix` | `string` | `"oci-arm"` | Prefix for resource display names and DNS labels |
| `ocpus` | `number` | `4` | ARM OCPUs (Always Free max: 4 total) |
| `memory_in_gbs` | `number` | `24` | Memory in GB (Always Free max: 24 total) |
| `boot_volume_size_in_gbs` | `number` | `47` | Boot volume in GB (Always Free max: 200 total) |
| `assign_public_ip` | `bool` | `true` | Assign a public IP (disable once you have alternative access, e.g., VPN) |

---

## Usage

1. **Initialize** the Terraform working directory:
   ```bash
   terraform init
   ```

2. **Preview** what will be created:
   ```bash
   terraform plan
   ```

3. **Apply** to create the instance and networking:
   ```bash
   terraform apply
   ```

4. **SSH in** once the instance is running:
   ```bash
   ssh -i ~/.ssh/your-key ubuntu@$(terraform output -raw instance_public_ip)
   ```

---

## Always Free Guardrails

The defaults stay within free-tier limits. If you change them, make sure the totals across all your instances stay under these caps:

| Resource | This stack uses | Always Free limit |
|----------|----------------|-------------------|
| ARM OCPUs | 4 | 4 total |
| Memory | 24 GB | 24 GB total |
| Boot volume | 47 GB | 200 GB total |
| Instances | 1 | Up to 4 ARM + 2 AMD |
| VCN | 1 | Included |

---

## Tearing Down

```bash
terraform destroy
```

Removes the instance, VCN, subnet, and gateway. Terraform state tracks what was created, so the destroy is clean and complete.

---

## Notes

- **OCI authentication**: The provider uses `~/.oci/config` by default. See the [OCI Terraform provider docs](https://registry.terraform.io/providers/oracle/oci/latest/docs) for alternatives (env vars, instance principal, etc.).

- **Public IP lifecycle**: Once you have alternative access (e.g., VPN or Tailscale), set `assign_public_ip = false` and run `terraform apply` again to drop the public IP.

- **Finding your OCIDs**:
  ```bash
  # Compartment (tenancy OCID)
  oci iam compartment list --query 'data[0]."compartment-id"' --raw-output

  # Available regions
  oci iam region list --query 'data[*].name' --raw-output
  ```
