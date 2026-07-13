################################################################################
# Outputs
################################################################################

output "availability_zones" {
  description = "AZ names the subnets are spread across."
  value       = module.subnet_calculator.availability_zones
}

output "newbits" {
  description = "Subnet mask growth applied to the VPC CIDR."
  value       = module.subnet_calculator.newbits
}

output "subnet_cidrs" {
  description = "Carved CIDRs per tier."
  value       = module.subnet_calculator.subnet_cidrs
}
