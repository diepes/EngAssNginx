# SG for ec2 instances

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.7.0"

  name        = "${var.prefix}-server"
  description = "Security group for web EC2 instance"
  vpc_id      = module.vpc.vpc_id

  # https://github.com/terraform-aws-modules/terraform-aws-security-group/blob/master/rules.tf
  ingress_ipv6_cidr_blocks = []
  ingress_cidr_blocks = []
  ingress_rules = []
  #
  egress_ipv6_cidr_blocks = []
  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["https-443-tcp", "all-icmp",] # Used for git, updates, SSM

  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "all-all"
      source_security_group_id = aws_security_group.lb.id
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1
}