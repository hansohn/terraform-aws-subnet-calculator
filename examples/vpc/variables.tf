################################################################################
# Provider
################################################################################

variable "region" {
  type        = string
  default     = null
  description = "If specified, the AWS region to deploy into. Otherwise, the region used by the callee"
}

################################################################################
# Variables
################################################################################

variable "cidr_block" {
  type        = string
  default     = "10.0.0.0/16"
  description = "IPv4 CIDR block for the VPC"
}
