#!/usr/bin/env bash
# ABOUTME: Pre-flight check for OCI Terraform stack prerequisites.
# ABOUTME: Validates tooling, credentials, and config before you run terraform init.

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass=0
warn=0
fail=0

ok()   { pass=$((pass + 1)); printf "${GREEN}[ok]${NC}   %s\n" "$1"; }
skip() { warn=$((warn + 1)); printf "${YELLOW}[warn]${NC} %s\n" "$1"; }
die()  { fail=$((fail + 1)); printf "${RED}[FAIL]${NC} %s\n" "$1"; }

# --- Terraform ---
if command -v terraform &>/dev/null; then
    ok "terraform found: $(terraform version -json 2>/dev/null | head -1 | grep -o '"[0-9][^"]*"' | tr -d '"' || terraform version | head -1)"
else
    die "terraform not found. Install: https://developer.hashicorp.com/terraform/install"
fi

# --- OCI CLI ---
if command -v oci &>/dev/null; then
    ok "oci cli found: $(oci --version 2>&1 | head -1)"
else
    die "oci cli not found. Install: uv tool install oci-cli (or pipx install oci-cli)"
fi

# --- ~/.oci/config ---
OCI_CONFIG="${OCI_CLI_CONFIG_FILE:-$HOME/.oci/config}"
if [[ -f "$OCI_CONFIG" ]]; then
    ok "oci config found: $OCI_CONFIG"

    # Check required fields
    for field in user fingerprint tenancy key_file region; do
        if grep -q "^${field}=" "$OCI_CONFIG" 2>/dev/null; then
            ok "  config has '$field'"
        else
            die "  config missing '$field'"
        fi
    done

    # Check PEM key file
    key_file=$(grep '^key_file=' "$OCI_CONFIG" | head -1 | cut -d= -f2 | sed "s|~|$HOME|")
    if [[ -n "$key_file" && -f "$key_file" ]]; then
        ok "  private key exists: $key_file"

        # Check for trailing junk after PEM end marker
        last_content=$(tail -1 "$key_file" | tr -d '[:space:]')
        if [[ "$last_content" == "-----ENDPRIVATEKEY-----" || "$last_content" == "-----ENDRSAPRIVATEKEY-----" ]]; then
            ok "  private key PEM format is clean"
        else
            die "  private key has trailing data after END marker (will cause intermittent Terraform 401s)"
            printf "       Fix: remove everything after '-----END PRIVATE KEY-----' in %s\n" "$key_file"
        fi

        # Check permissions
        perms=$(stat -c '%a' "$key_file" 2>/dev/null || stat -f '%Lp' "$key_file" 2>/dev/null)
        if [[ "$perms" == "600" || "$perms" == "400" ]]; then
            ok "  private key permissions: $perms"
        else
            skip "  private key permissions are $perms (should be 600 or 400)"
        fi
    elif [[ -n "$key_file" ]]; then
        die "  private key not found: $key_file"
    fi
else
    die "oci config not found at $OCI_CONFIG"
    printf "       Run: oci setup config\n"
    printf "       Docs: https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm\n"
fi

# --- SSH key ---
ssh_path=""
if [[ -f "terraform.tfvars" ]]; then
    ssh_path=$(grep '^ssh_public_key_path' terraform.tfvars 2>/dev/null | sed 's/.*=\s*"\(.*\)"/\1/' | sed "s|~|$HOME|" || true)
fi
ssh_path="${ssh_path:-$HOME/.ssh/id_ed25519.pub}"

if [[ -f "$ssh_path" ]]; then
    ok "ssh public key found: $ssh_path"
else
    die "ssh public key not found: $ssh_path"
    printf "       Generate: ssh-keygen -t ed25519\n"
fi

# --- terraform.tfvars ---
if [[ -f "terraform.tfvars" ]]; then
    ok "terraform.tfvars exists"

    if grep -q 'compartment_id.*=.*"ocid1\.' terraform.tfvars 2>/dev/null; then
        ok "  compartment_id is set"
    else
        die "  compartment_id not set (or still has placeholder)"
    fi

    if grep -q 'region.*=.*"[a-z]' terraform.tfvars 2>/dev/null; then
        ok "  region is set"
    else
        die "  region not set"
    fi
else
    die "terraform.tfvars not found. Run: cp terraform.tfvars.example terraform.tfvars"
fi

# --- Live auth check ---
if command -v oci &>/dev/null && [[ -f "$OCI_CONFIG" ]]; then
    printf "\n  Testing OCI API authentication...\n"
    if oci iam region list --query 'data[0].name' --raw-output &>/dev/null; then
        ok "oci api authentication works"
    else
        die "oci api authentication failed (check config, key, and that public key is uploaded to OCI console)"
    fi
fi

# --- Summary ---
printf "\n"
printf "  %s passed, %s warnings, %s failed\n" "$pass" "$warn" "$fail"

if ((fail > 0)); then
    printf "\n${RED}  Fix the failures above before running terraform init.${NC}\n\n"
    exit 1
else
    printf "\n${GREEN}  Ready to go. Run: terraform init && terraform plan${NC}\n\n"
    exit 0
fi
