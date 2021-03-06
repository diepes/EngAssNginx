locals {
  region = var.aws_region
}

# output "debug_module_vpc" { value = module.vpc }
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.11.0"

  name = var.prefix
  cidr = "10.0.0.0/16"

  azs             = ["${local.region}a", "${local.region}b", "${local.region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  #azs              = ["${local.region}a",]
  #public_subnets  = ["10.0.101.0/24", ]

  enable_ipv6 = false

  enable_nat_gateway = true
  single_nat_gateway = true

  # dns support needed for VPC Endpoint
  enable_dns_support   = true
  enable_dns_hostnames = true

  # public_subnet_tags = {
  #   Name = "${var.prefix}-public"
  # }

  tags = var.tags

  vpc_tags = merge(var.tags,
    { Name = "${var.prefix}-vpc" },
  )
}