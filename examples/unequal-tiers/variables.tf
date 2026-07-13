################################################################################
# Provider
################################################################################

variable "region" {
  type        = string
  default     = null
  description = "If specified, the AWS region to deploy into. Otherwise, the region used by the callee"
}
