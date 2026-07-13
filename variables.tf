################################################################################
# Variables
################################################################################

variable "cidr_block" {
  description = "IPv4 CIDR block for the VPC from which subnet ranges are carved (e.g. \"10.0.0.0/16\")."
  type        = string
}

variable "tiers" {
  description = <<-EOT
    Ordered list of subnet tier names to carve. Order determines CIDR allocation:
    tier 0 occupies the first `az_count` blocks, tier 1 the next, and so on. Adding,
    removing, or reordering tiers changes every downstream CIDR, so treat this as
    immutable for a live VPC.
  EOT
  type        = list(string)
  default     = ["public", "protected", "private"]

  validation {
    condition     = length(var.tiers) == length(distinct(var.tiers))
    error_message = "Tier names must be unique."
  }
}

variable "enable_dynamic_subnets" {
  description = "When true, CIDRs are computed automatically from `cidr_block`. When false, `static_subnet_cidrs` is used verbatim."
  type        = bool
  default     = true
}

################################################################################
# Dynamic Mode
################################################################################

variable "availability_zones" {
  description = "Explicit AZ names to spread subnets across. When empty, AZs are auto-discovered for the current region."
  type        = list(string)
  default     = []
}

variable "max_availability_zones" {
  description = "Cap on the number of auto-discovered AZs. Ignored when `availability_zones` is set."
  type        = number
  default     = 3
}

variable "exclude_availability_zone_names" {
  description = "AZ names to exclude from auto-discovery."
  type        = list(string)
  default     = []
}

variable "exclude_availability_zone_ids" {
  description = "AZ IDs to exclude from auto-discovery."
  type        = list(string)
  default     = []
}

variable "newbits_override" {
  description = "Override the auto-computed subnet mask growth (newbits). null = auto: ceil(log2(tiers * azs))."
  type        = number
  default     = null
}

################################################################################
# Static Mode
################################################################################

variable "static_subnet_cidrs" {
  description = <<-EOT
    Explicit CIDRs used when `enable_dynamic_subnets = false`.
    Shape: tier name => AZ name => list of CIDR strings.
    Example: { public = { "us-west-2a" = ["10.0.0.0/24"] } }
  EOT
  type        = map(map(list(string)))
  default     = {}
}
