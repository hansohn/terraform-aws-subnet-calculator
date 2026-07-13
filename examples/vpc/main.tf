################################################################################
# Main
#
# Demonstrates the intended pattern: the calculator does the CIDR math, and
# terraform-aws-modules/vpc builds the actual VPC. The `protected` tier maps to
# upstream's `intra` subnets (routable internally, no NAT).
################################################################################

provider "aws" {
  region = var.region
}

module "subnet_calculator" {
  source = "../../"

  cidr_block             = var.cidr_block
  tiers                  = ["public", "protected", "private"]
  max_availability_zones = 3
  enable_dynamic_subnets = true
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "subnet-calculator-example"
  cidr = var.cidr_block

  azs             = module.subnet_calculator.availability_zones
  public_subnets  = module.subnet_calculator.subnet_cidrs["public"]
  intra_subnets   = module.subnet_calculator.subnet_cidrs["protected"]
  private_subnets = module.subnet_calculator.subnet_cidrs["private"]

  enable_nat_gateway = true
  single_nat_gateway = true
}
