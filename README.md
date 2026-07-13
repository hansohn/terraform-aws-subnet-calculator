<div align="center">
  <h3>terraform-aws-subnet-calculator</h3>
  <p>Terraform module to calculate non-overlapping subnet CIDRs across availability zones and tiers</p>
  <p>
    <!-- Build Status -->
    <a href="https://actions-badge.atrox.dev/hansohn/terraform-aws-subnet-calculator/goto?ref=main">
      <img src="https://img.shields.io/endpoint.svg?url=https%3A%2F%2Factions-badge.atrox.dev%2Fhansohn%2Fterraform-aws-subnet-calculator%2Fbadge%3Fref%3Dmain&style=for-the-badge">
    </a>
    <!-- Github Tag -->
    <a href="https://gitHub.com/hansohn/terraform-aws-subnet-calculator/tags/">
      <img src="https://img.shields.io/github/tag/hansohn/terraform-aws-subnet-calculator.svg?style=for-the-badge">
    </a>
    <!-- License -->
    <a href="https://github.com/hansohn/terraform-aws-subnet-calculator/blob/main/LICENSE">
      <img src="https://img.shields.io/github/license/hansohn/terraform-aws-subnet-calculator.svg?style=for-the-badge">
    </a>
  </p>
</div>

## :open_book: Usage

A **resource-free** helper that carves a VPC CIDR into non-overlapping, equal-sized
subnet ranges — one per (tier, availability zone) — and returns them as lists ready
to hand to any VPC module. It fills the CIDR-math gap that
[`terraform-aws-modules/vpc`](https://github.com/terraform-aws-modules/terraform-aws-vpc)
leaves to the caller, without provisioning anything or depending on CloudPosse null-label.

Given just a CIDR block, it auto-discovers AZs and auto-sizes the subnet mask
(`newbits = ceil(log2(tiers * azs))`) so tiers can never overlap:

```hcl
module "subnet_calculator" {
  source = "hansohn/subnet-calculator/aws"

  cidr_block             = "10.0.0.0/16"
  tiers                  = ["public", "protected", "private"]
  max_availability_zones = 3
  enable_dynamic_subnets = true
}

# module.subnet_calculator.subnet_cidrs = {
#   public    = ["10.0.0.0/20",  "10.0.16.0/20",  "10.0.32.0/20"]
#   protected = ["10.0.48.0/20",  "10.0.64.0/20",  "10.0.80.0/20"]
#   private   = ["10.0.96.0/20",  "10.0.112.0/20", "10.0.128.0/20"]
# }
```

Feed the outputs directly into a VPC module:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "example"
  cidr = "10.0.0.0/16"

  azs             = module.subnet_calculator.availability_zones
  public_subnets  = module.subnet_calculator.subnet_cidrs["public"]
  intra_subnets   = module.subnet_calculator.subnet_cidrs["protected"]
  private_subnets = module.subnet_calculator.subnet_cidrs["private"]
}
```

### Availability zone alignment

`availability_zones` and each `subnet_cidrs[<tier>]` list are **index-aligned**:
entry `i` of a tier's CIDR list is the subnet computed for `availability_zones[i]`,
and every tier shares the same AZ order (so `public[0]`, `private[0]`, … all land
in the first AZ). VPC modules zip these by position — `terraform-aws-modules/vpc`
assigns `element(var.azs, count.index)` alongside `var.public_subnets[count.index]`.

Because of that, the rule is: **always pass this module's `availability_zones`
output as the VPC module's `azs`.** Sourcing `azs` from anywhere else (e.g. a
separate `slice(data.aws_availability_zones.available.names, ...)`) that is ordered
or filtered differently will silently place subnets in the wrong zone — the CIDRs
stay valid and non-overlapping, so nothing errors. Use the `subnet_azs[<tier>]`
output to assert the pairing:

```hcl
output "public_pairs" {
  value = zipmap(
    module.subnet_calculator.subnet_azs["public"],
    module.subnet_calculator.subnet_cidrs["public"],
  )
  # => { "us-west-2a" = "10.0.0.0/20", "us-west-2b" = "10.0.16.0/20", ... }
}
```

### Unequal tier sizing

By default every subnet is equal-sized. To make tiers differ, set `tier_newbits` —
a per-tier mask growth (bigger = smaller tier). Sizes are powers of two, so you
express **relative ratios**, not arbitrary percentages:

```hcl
module "subnet_calculator" {
  source = "hansohn/subnet-calculator/aws"

  cidr_block   = "10.0.0.0/16"
  tiers        = ["public", "private", "internal"]
  tier_newbits = { public = 3, private = 2, internal = 2 } # ratio 1:2:2

  # public   = ["10.0.0.0/21", "10.0.8.0/21",  "10.0.16.0/21"]   (half size)
  # private  = ["10.0.64.0/20","10.0.80.0/20",  "10.0.96.0/20"]
  # internal = ["10.0.128.0/20","10.0.144.0/20","10.0.160.0/20"]
}
```

For fully manual control, set `enable_dynamic_subnets = false` and pass
`static_subnet_cidrs`.

> [!WARNING]
> The mask is derived from `tiers * azs` (or `tier_newbits`). Adding an AZ or a
> tier changes the layout, which re-CIDRs every subnet and forces recreation.
> Treat the tier list and AZ count as immutable for a live VPC, or pin CIDRs via
> static mode. Power-of-two sizing means unequal splits may leave alignment gaps
> between tiers (expected, not overlap).

## :sparkles: Examples

Please see the sample set of examples below for a better understanding of implementation

- [Complete](examples/complete) - Standalone calculator usage
- [Unequal Tiers](examples/unequal-tiers) - Per-tier sizing with `tier_newbits`
- [VPC](examples/vpc) - Wiring the calculator into `terraform-aws-modules/vpc`

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | Explicit AZ names to spread subnets across. When empty, AZs are auto-discovered for the current region. | `list(string)` | `[]` | no |
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | IPv4 CIDR block for the VPC from which subnet ranges are carved (e.g. "10.0.0.0/16"). | `string` | n/a | yes |
| <a name="input_enable_dynamic_subnets"></a> [enable\_dynamic\_subnets](#input\_enable\_dynamic\_subnets) | When true, CIDRs are computed automatically from `cidr_block`. When false, `static_subnet_cidrs` is used verbatim. | `bool` | `true` | no |
| <a name="input_exclude_availability_zone_ids"></a> [exclude\_availability\_zone\_ids](#input\_exclude\_availability\_zone\_ids) | AZ IDs to exclude from auto-discovery. | `list(string)` | `[]` | no |
| <a name="input_exclude_availability_zone_names"></a> [exclude\_availability\_zone\_names](#input\_exclude\_availability\_zone\_names) | AZ names to exclude from auto-discovery. | `list(string)` | `[]` | no |
| <a name="input_max_availability_zones"></a> [max\_availability\_zones](#input\_max\_availability\_zones) | Cap on the number of auto-discovered AZs. Ignored when `availability_zones` is set. | `number` | `3` | no |
| <a name="input_newbits_override"></a> [newbits\_override](#input\_newbits\_override) | Override the auto-computed subnet mask growth (newbits). null = auto: ceil(log2(tiers * azs)). | `number` | `null` | no |
| <a name="input_static_subnet_cidrs"></a> [static\_subnet\_cidrs](#input\_static\_subnet\_cidrs) | Explicit CIDRs used when `enable_dynamic_subnets = false`.<br/>Shape: tier name => AZ name => list of CIDR strings.<br/>Example: { public = { "us-west-2a" = ["10.0.0.0/24"] } } | `map(map(list(string)))` | `{}` | no |
| <a name="input_tier_newbits"></a> [tier\_newbits](#input\_tier\_newbits) | Optional per-tier mask growth for unequal tier sizing. Map of tier name => newbits<br/>(bits added to the VPC prefix for that tier's block; larger = smaller tier). Empty<br/>means all tiers are equal-sized (default behavior). When set, an entry is required<br/>for every tier in `tiers`. Sizes are powers of two, so express relative sizes as<br/>ratios, e.g. { public = 3, private = 2, internal = 2 } => 1:2:2. | `map(number)` | `{}` | no |
| <a name="input_tiers"></a> [tiers](#input\_tiers) | Ordered list of subnet tier names to carve. Order determines CIDR allocation:<br/>tier 0 occupies the first `az_count` blocks, tier 1 the next, and so on. Adding,<br/>removing, or reordering tiers changes every downstream CIDR, so treat this as<br/>immutable for a live VPC. | `list(string)` | <pre>[<br/>  "public",<br/>  "protected",<br/>  "private"<br/>]</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_availability_zones"></a> [availability\_zones](#output\_availability\_zones) | Ordered list of AZ names the subnets are spread across. |
| <a name="output_newbits"></a> [newbits](#output\_newbits) | Subnet mask growth applied to cidr\_block (auto-computed unless overridden). |
| <a name="output_subnet_azs"></a> [subnet\_azs](#output\_subnet\_azs) | Map of tier name => ordered list of AZ names, index-aligned with subnet\_cidrs. |
| <a name="output_subnet_cidrs"></a> [subnet\_cidrs](#output\_subnet\_cidrs) | Map of tier name => ordered list of CIDR strings. Index-aligned with subnet\_azs. Ready to pass as public\_subnets/private\_subnets/intra\_subnets. |
| <a name="output_subnets"></a> [subnets](#output\_subnets) | Map of tier name => ordered list of { availability\_zone, cidr\_block } objects. |
<!-- END_TF_DOCS -->

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
