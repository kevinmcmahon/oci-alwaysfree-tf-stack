#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_ROOT="$BATS_TEST_TMPDIR/root"
  TEST_HOME="$TEST_ROOT/home"
  TEST_BIN="$TEST_ROOT/bin"
  mkdir -p "$TEST_HOME/.oci" "$TEST_HOME/.ssh/identities" "$TEST_BIN"

  cat >"$TEST_BIN/terraform" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == version && "${2:-}" == -json ]]; then
  printf '%s\n' '{"terraform_version":"1.15.8"}'
else
  printf '%s\n' 'Terraform v1.15.8'
fi
EOF

  cat >"$TEST_BIN/oci" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == --version ]]; then
  printf '%s\n' '3.90.3'
fi
exit 0
EOF
  chmod +x "$TEST_BIN/terraform" "$TEST_BIN/oci"

  cat >"$TEST_HOME/.oci/config" <<EOF
user=ocid1.user.test
fingerprint=00:11:22
tenancy=ocid1.tenancy.test
key_file=$TEST_HOME/.oci/oci_api_key.pem
region=us-chicago-1
EOF

  cat >"$TEST_ROOT/terraform.tfvars" <<'EOF'
compartment_id = "ocid1.tenancy.test"
region = "us-chicago-1"
EOF

  : >"$TEST_HOME/.ssh/id_ed25519.pub"
}

run_preflight() {
  cd "$TEST_ROOT"
  run env \
    HOME="$TEST_HOME" \
    PATH="$TEST_BIN:/usr/bin:/bin" \
    OCI_CLI_CONFIG_FILE="$TEST_HOME/.oci/config" \
    "$REPO_ROOT/preflight.sh"
}

@test "preflight accepts an encrypted PKCS8 private-key footer" {
  cat >"$TEST_HOME/.oci/oci_api_key.pem" <<'EOF'
-----BEGIN ENCRYPTED PRIVATE KEY-----
fixture
-----END ENCRYPTED PRIVATE KEY-----
EOF
  chmod 600 "$TEST_HOME/.oci/oci_api_key.pem"

  run_preflight

  [ "$status" -eq 0 ]
  [[ "$output" == *"private key PEM format is clean"* ]]
  [[ "$output" == *"0 failed"* ]]
}

@test "preflight parses a spaced SSH public-key assignment portably" {
  cat >"$TEST_HOME/.oci/oci_api_key.pem" <<'EOF'
-----BEGIN PRIVATE KEY-----
fixture
-----END PRIVATE KEY-----
EOF
  chmod 600 "$TEST_HOME/.oci/oci_api_key.pem"
  : >"$TEST_HOME/.ssh/identities/operator.pub"
  cat >>"$TEST_ROOT/terraform.tfvars" <<'EOF'
ssh_public_key_path = "~/.ssh/identities/operator.pub"
EOF

  run_preflight

  [ "$status" -eq 0 ]
  [[ "$output" == *"ssh public key found: $TEST_HOME/.ssh/identities/operator.pub"* ]]
  [[ "$output" == *"0 failed"* ]]
}
