################################################################################
# Main
################################################################################

# Pure-computation helper. Given a VPC CIDR and a set of tiers, it auto-discovers
# AZs and carves non-overlapping, equal-sized subnet ranges — one per (tier, AZ) —
# with an automatically sized mask. Emits CIDR/AZ lists shaped for consumption by
# terraform-aws-modules/vpc (or any VPC module). Set enable_dynamic_subnets = false
# to pass CIDRs through verbatim.

data "aws_availability_zones" "available" {
  count            = var.enable_dynamic_subnets && length(var.availability_zones) == 0 ? 1 : 0
  exclude_names    = var.exclude_availability_zone_names
  exclude_zone_ids = var.exclude_availability_zone_ids
  state            = "available"
}

locals {
  # Resolve AZs: explicit list wins; otherwise take the first N discovered.
  discovered_azs = length(var.availability_zones) > 0 ? var.availability_zones : (
    length(data.aws_availability_zones.available) > 0 ? slice(
      data.aws_availability_zones.available[0].names,
      0,
      min(length(data.aws_availability_zones.available[0].names), var.max_availability_zones)
    ) : []
  )

  az_count   = length(local.discovered_azs)
  tier_count = length(var.tiers)

  # Bits of extra mask needed to fit (tiers * azs) subnets inside cidr_block.
  # e.g. 3 tiers * 3 azs = 9 subnets -> ceil(log2(9)) = 4 -> /16 becomes /20.
  auto_newbits = local.tier_count * local.az_count > 0 ? ceil(log(local.tier_count * local.az_count, 2)) : 0
  newbits      = coalesce(var.newbits_override, local.auto_newbits)

  # Dynamic: tier `ti` occupies netnums [ti*az_count .. ti*az_count+az_count-1],
  # so tiers never overlap and each AZ gets one block per tier.
  dynamic_subnets = {
    for ti, tier in var.tiers : tier => [
      for ai, az in local.discovered_azs : {
        availability_zone = az
        cidr_block        = cidrsubnet(var.cidr_block, local.newbits, ti * local.az_count + ai)
      }
    ]
  }

  # Unequal tiers: carve one variable-sized block per tier (level 1), then split
  # each tier block evenly across AZs (level 2). Powers of two only, so blocks may
  # leave alignment gaps between tiers — that is expected, not overlap.
  use_tier_sizing = var.enable_dynamic_subnets && length(var.tier_newbits) > 0
  tier_blocks     = local.use_tier_sizing ? cidrsubnets(var.cidr_block, [for t in var.tiers : var.tier_newbits[t]]...) : []
  az_newbits      = local.az_count > 0 ? ceil(log(local.az_count, 2)) : 0
  sized_subnets = local.use_tier_sizing ? {
    for ti, tier in var.tiers : tier => [
      for ai, az in local.discovered_azs : {
        availability_zone = az
        cidr_block        = cidrsubnet(local.tier_blocks[ti], local.az_newbits, ai)
      }
    ]
  } : {}

  # Static: flatten { tier => { az => [cidrs] } } into per-tier ordered lists.
  static_subnets = {
    for tier in var.tiers : tier => flatten([
      for az in sort(keys(lookup(var.static_subnet_cidrs, tier, {}))) : [
        for cidr in var.static_subnet_cidrs[tier][az] : {
          availability_zone = az
          cidr_block        = cidr
        }
      ]
    ])
  }

  subnets = !var.enable_dynamic_subnets ? local.static_subnets : (
    local.use_tier_sizing ? local.sized_subnets : local.dynamic_subnets
  )
}
