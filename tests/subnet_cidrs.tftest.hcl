mock_provider "aws" {}

variables {
  cidr_block         = "10.0.0.0/16"
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  tiers              = ["public", "private", "internal"]
}

# Default (no tier_newbits): equal-sized subnets. Values must stay identical to
# the 1.0.0 release so existing consumers are unaffected.
run "equal_sized_default" {
  command = plan

  assert {
    condition     = output.newbits == 4
    error_message = "expected newbits 4 for 3 tiers x 3 azs"
  }
  assert {
    condition     = output.subnet_cidrs["public"] == ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
    error_message = "public equal-sized CIDRs changed"
  }
  assert {
    condition     = output.subnet_cidrs["private"] == ["10.0.48.0/20", "10.0.64.0/20", "10.0.80.0/20"]
    error_message = "private equal-sized CIDRs changed"
  }
  assert {
    condition     = output.subnet_cidrs["internal"] == ["10.0.96.0/20", "10.0.112.0/20", "10.0.128.0/20"]
    error_message = "internal equal-sized CIDRs changed"
  }
}

# Unequal tiers: public half the size of private/internal (ratio 1:2:2).
run "unequal_tier_sizing" {
  command = plan

  variables {
    tier_newbits = { public = 3, private = 2, internal = 2 }
  }

  assert {
    condition     = output.subnet_cidrs["public"] == ["10.0.0.0/21", "10.0.8.0/21", "10.0.16.0/21"]
    error_message = "public should be /21 (half size)"
  }
  assert {
    condition     = output.subnet_cidrs["private"] == ["10.0.64.0/20", "10.0.80.0/20", "10.0.96.0/20"]
    error_message = "private /20 CIDRs incorrect"
  }
  assert {
    condition     = output.subnet_cidrs["internal"] == ["10.0.128.0/20", "10.0.144.0/20", "10.0.160.0/20"]
    error_message = "internal /20 CIDRs incorrect"
  }
}

# Validation: tier_newbits must cover every tier when set.
run "tier_newbits_requires_all_tiers" {
  command = plan

  variables {
    tier_newbits = { public = 3 }
  }

  expect_failures = [
    var.tier_newbits,
  ]
}
