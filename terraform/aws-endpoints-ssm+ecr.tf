# Add Private Endpoints for SSM to the DMZ VPC, so we can manage the instances.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint

locals {
  pvtlink_endpoints = {
    ssm         = "com.amazonaws.${var.aws_region}.ssm"
    ssmmessages = "com.amazonaws.${var.aws_region}.ssmmessages"
    ec2messages = "com.amazonaws.${var.aws_region}.ec2messages"
    ecr-dkr     = "com.amazonaws.${var.aws_region}.ecr.dkr"
    ecr-api     = "com.amazonaws.${var.aws_region}.ecr.api"
    #ecr-public  = "com.amazonaws.${var.aws_region}.ecr-public"
    ecr-public  = "com.amazonaws.us-east-1.ecr-public"
  }

  #  https://www.terraform.io/docs/language/functions/flatten.html#flattening-nested-structures-for-for_each
  vpc_endpoint_subnet_associations = flatten(
    [for s in module.vpc.private_subnets : [
      for e in aws_vpc_endpoint.pvtlink : {
        name        = join("_", [e.service_name, s, ])
        endpoint_id = e.id
        subnet_id   = s
      }
      ]
    ]
  )

} # End locals

resource "aws_vpc_endpoint" "s3" {
  vpc_id          = module.vpc.vpc_id
  service_name    = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = module.vpc.private_route_table_ids
  tags            = merge(var.tags, { Name = join("-", [var.prefix, "s3", ]) })
}

# Interface Endpoint Type
resource "aws_vpc_endpoint" "pvtlink" {
  for_each          = local.pvtlink_endpoints
  vpc_id            = module.vpc.vpc_id
  service_name      = each.value
  vpc_endpoint_type = "Interface" # Type Interface requires a SG
  security_group_ids = [
    aws_security_group.allow_pvtlink_tls.id,
  ]
  private_dns_enabled = true
  tags                = merge(var.tags, { Name = join("-", [var.prefix, each.key, ]) })
}

resource "aws_vpc_endpoint_subnet_association" "pvtlink" {
  for_each        = { for assoc in local.vpc_endpoint_subnet_associations : "${assoc.name}" => assoc }
  vpc_endpoint_id = each.value["endpoint_id"]
  subnet_id       = each.value["subnet_id"]
}


resource "aws_security_group" "allow_pvtlink_tls" {
  name        = "allow_pvtlink_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
    #ipv6_cidr_blocks = [aws_vpc.dmzAV.ipv6_cidr_block]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = var.tags
}