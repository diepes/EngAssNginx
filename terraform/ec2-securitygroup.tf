# SG for ec2 instances
# first find private ips of LB
data "aws_network_interface" "lb" {
  for_each = toset(module.vpc.public_subnets)
  filter {
    name   = "description"
    values = ["ELB ${aws_lb.server.arn_suffix}"]
  }
  filter {
    name   = "subnet-id"
    values = [each.value]
  }
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.7.0"

  name        = "${var.prefix}-server"
  description = "Security group for web EC2 instance"
  vpc_id      = module.vpc.vpc_id

  # https://github.com/terraform-aws-modules/terraform-aws-security-group/blob/master/rules.tf
  ## ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_cidr_blocks = formatlist("%s/32", [for eni in data.aws_network_interface.lb : eni.private_ip])
  ingress_ipv6_cidr_blocks = []
  ingress_rules       = ["all-icmp", "http-8080-tcp", "http-80-tcp"]  #No inbound only icmp
  #ingress_with_cidr_blocks = []
  #
  egress_ipv6_cidr_blocks = []
  egress_rules = ["https-443-tcp", "all-icmp",] # Used for git, updates, SSM
}