################################################################################
# Outputs
################################################################################

output "computed_subnet_cidrs" {
  description = "CIDRs the calculator carved, per tier."
  value       = module.subnet_calculator.subnet_cidrs
}

output "vpc_id" {
  description = "ID of the VPC created by terraform-aws-modules/vpc."
  value       = module.vpc.vpc_id
}
