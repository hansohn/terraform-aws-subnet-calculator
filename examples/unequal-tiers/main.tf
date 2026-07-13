################################################################################
# Main
#
# Unequal per-tier sizing: public subnets are half the size of private/internal
# (ratio 1:2:2). Sizes are powers of two, so relative ratios — not arbitrary
# percentages — are what you express via tier_newbits.
################################################################################

provider "aws" {
  region = var.region
}

module "subnet_calculator" {
  source = "../../"

  cidr_block             = "10.0.0.0/16"
  tiers                  = ["public", "private", "internal"]
  max_availability_zones = 3
  enable_dynamic_subnets = true

  tier_newbits = {
    public   = 3 # /19 tier block -> smaller subnets
    private  = 2 # /18 tier block
    internal = 2 # /18 tier block
  }
}
