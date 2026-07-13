################################################################################
# Outputs
################################################################################

output "subnet_cidrs" {
  description = "Carved CIDRs per tier (public half the size of private/internal)."
  value       = module.subnet_calculator.subnet_cidrs
}
