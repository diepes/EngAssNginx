resource "aws_instance" "server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  #
  #subnet_id = aws_subnet.public.id
  subnet_id = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  vpc_security_group_ids = flatten([
                              module.security_group.security_group_id, 
                            ])
  key_name = aws_key_pair.ssh_key.key_name
  #user_data
  #user_data_base64 = filebase64("ec2-userdata.txt")
  user_data_base64 = base64encode(templatefile("ec2-userdata.txt",{ HOSTNAME = "${var.prefix}-web-server" }))
  tags = {
    Name = "${var.prefix}-web-server"
  }
#   launch_template {
#       name = "setup"
#   }
}
output "aws_instance_server_public_ip" {
    value = aws_instance.server.public_ip
}

# Note: key will be replaced everytime
resource "aws_key_pair" "ssh_key" {
  key_name   = "nginx_server"
  public_key = file(pathexpand(var.pub_key_path))
}

data "aws_ami" "debian" {
  # aws ec2 describe-images --filter=Name=product-code,Values=auhljmclkudu651zy27rih2x2 --output json
  # login user admin@
  # require AWS OptInRequired: , acceptance of licence.
  most_recent = true
  owners = ["aws-marketplace"]
  filter {
    name   = "name"
    values = ["debian-10-amd64*",]
  }
  filter {
      #name = "ProductCodes[*].ProductCodeId"
      name = "product-code"
      values = ["auhljmclkudu651zy27rih2x2",]
  }
  filter {
      name = "virtualization-type"
      values = ["hvm"]
  }
}
data "aws_ami" "amazon_linux" {
  # login user ec2-user@
  most_recent = true
  owners = ["amazon"]
  filter {
    name = "name"
    values = ["amzn-ami-hvm-*-x86_64-gp2", ]
  }
  filter {
    name = "owner-alias"
    values = ["amazon", ]
  }
  filter {
      name = "virtualization-type"
      values = ["hvm"]
  }
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.7.0"

  name        = "${var.prefix}-sg"
  description = "Security group for web EC2 instance"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  # https://github.com/terraform-aws-modules/terraform-aws-security-group/blob/master/rules.tf
  ingress_rules       = ["https-443-tcp", "http-80-tcp", "all-icmp", "ssh-tcp"]
  egress_rules        = ["all-all"]
}