mock_provider "oci" {}

override_data {
  target = data.oci_identity_availability_domains.ads
  values = {
    availability_domains = [{ name = "AD-1" }]
  }
}

override_data {
  target = data.oci_core_images.ubuntu
  values = {
    images = [{ id = "ocid1.image.oc1.example" }]
  }
}

variables {
  compartment_id = "ocid1.tenancy.oc1..example"
  region         = "us-chicago-1"
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest hermes-test"
}

run "closed_bootstrap_access" {
  command = plan

  assert {
    condition     = length([for rule in oci_core_default_security_list.this.ingress_security_rules : rule if rule.protocol == "6"]) == 0
    error_message = "Null bootstrap_ssh_cidr must create no TCP ingress rule."
  }

  assert {
    condition     = length([for rule in oci_core_default_security_list.this.ingress_security_rules : rule if rule.protocol == "17" && rule.source == "0.0.0.0/0"]) == 1
    error_message = "The public Tailscale UDP ingress rule must remain present."
  }

  assert {
    condition     = length([for rule in oci_core_default_security_list.this.ingress_security_rules : rule if rule.protocol == "1"]) == 2
    error_message = "Both OCI default ICMP ingress rules must remain present."
  }

  assert {
    condition     = length(oci_core_default_security_list.this.egress_security_rules) == 1 && one(oci_core_default_security_list.this.egress_security_rules).destination == "0.0.0.0/0"
    error_message = "Unrestricted IPv4 egress must remain present."
  }

  assert {
    condition     = oci_core_instance.this.create_vnic_details[0].assign_public_ip
    error_message = "The reference deployment must retain its public IP."
  }

  assert {
    condition     = oci_core_instance.this.source_details[0].boot_volume_size_in_gbs == "50"
    error_message = "The default boot volume must meet OCI's 50 GB minimum."
  }

  assert {
    condition     = output.bootstrap_ssh_access.enabled == false && output.bootstrap_ssh_access.cidr == null
    error_message = "The bootstrap access output must report closed access without exposing sensitive data."
  }
}

run "open_bootstrap_access" {
  command = plan

  variables {
    bootstrap_ssh_cidr = "198.51.100.42/32"
  }

  assert {
    condition     = length([for rule in oci_core_default_security_list.this.ingress_security_rules : rule if rule.protocol == "6" && rule.source == "198.51.100.42/32"]) == 1
    error_message = "A valid bootstrap CIDR must create exactly one scoped TCP ingress rule."
  }

  assert {
    condition     = one(one([for rule in oci_core_default_security_list.this.ingress_security_rules : rule if rule.protocol == "6"]).tcp_options).min == 22 && one(one([for rule in oci_core_default_security_list.this.ingress_security_rules : rule if rule.protocol == "6"]).tcp_options).max == 22
    error_message = "The temporary TCP rule must allow only destination port 22."
  }

  assert {
    condition     = output.bootstrap_ssh_access.enabled == true && output.bootstrap_ssh_access.cidr == "198.51.100.42/32"
    error_message = "The bootstrap access output must report the active scoped CIDR."
  }
}

run "rejects_broad_cidr" {
  command = plan

  variables {
    bootstrap_ssh_cidr = "198.51.100.0/24"
  }

  expect_failures = [var.bootstrap_ssh_cidr]
}

run "rejects_ipv6" {
  command = plan

  variables {
    bootstrap_ssh_cidr = "2001:db8::1/128"
  }

  expect_failures = [var.bootstrap_ssh_cidr]
}

run "rejects_invalid_ipv4" {
  command = plan

  variables {
    bootstrap_ssh_cidr = "999.51.100.42/32"
  }

  expect_failures = [var.bootstrap_ssh_cidr]
}

run "rejects_whitespace" {
  command = plan

  variables {
    bootstrap_ssh_cidr = " 198.51.100.42/32"
  }

  expect_failures = [var.bootstrap_ssh_cidr]
}

run "rejects_boot_volume_below_oci_minimum" {
  command = plan

  variables {
    boot_volume_size_in_gbs = 49
  }

  expect_failures = [var.boot_volume_size_in_gbs]
}
