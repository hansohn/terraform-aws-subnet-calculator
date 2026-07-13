################################################################################
# Outputs
################################################################################

output "availability_zones" {
  description = "Ordered list of AZ names the subnets are spread across."
  value       = local.discovered_azs
}

output "newbits" {
  description = "Subnet mask growth applied to cidr_block (auto-computed unless overridden)."
  value       = local.newbits
}

output "subnets" {
  description = "Map of tier name => ordered list of { availability_zone, cidr_block } objects."
  value       = local.subnets
}

output "subnet_cidrs" {
  description = "Map of tier name => ordered list of CIDR strings. Index-aligned with subnet_azs. Ready to pass as public_subnets/private_subnets/intra_subnets."
  value       = { for tier, subs in local.subnets : tier => [for s in subs : s.cidr_block] }
}

output "subnet_azs" {
  description = "Map of tier name => ordered list of AZ names, index-aligned with subnet_cidrs."
  value       = { for tier, subs in local.subnets : tier => [for s in subs : s.availability_zone] }
}
