################################################################################
# Main
################################################################################

provider "aws" {
  region = var.region
}

module "subnet_calculator" {
  source = "../../"

  cidr_block             = "10.0.0.0/16"
  tiers                  = ["public", "protected", "private"]
  max_availability_zones = 3
  enable_dynamic_subnets = true
}
