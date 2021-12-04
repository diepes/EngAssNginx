resource "aws_eip" "website" {
  vpc      = true
  tags = {
      Name = "${var.prefix}-web-server"
  }
}
resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.server.id
  allocation_id = aws_eip.website.id
}

resource "aws_instance" "server" {
  ami           = data.aws_ami.amazon-linux-2.id
  instance_type = "t2.micro"
  subnet_id = module.vpc.public_subnets[0]
  associate_public_ip_address = false  # Use eip
  vpc_security_group_ids = flatten([
                              module.security_group.security_group_id, 
                            ])
  key_name = aws_key_pair.ssh_key.key_name
  user_data_base64 = base64encode(templatefile("ec2-userdata.yaml",{ HOSTNAME = "${var.prefix}-web-server" }))
  tags = {
    Name = "${var.prefix}-web-server"
  }
}
output "aws_instance_server_public_ip" {
    value = aws_instance.server.public_ip
}

# Note: key will be replaced everytime
resource "aws_key_pair" "ssh_key" {
  key_name   = "nginx_server"
  public_key = file(pathexpand(var.pub_key_path))
}

data "aws_ami" "amazon-linux-2" {
  # login user ec2-user@
  most_recent = true
  owners = ["amazon"]
  filter {
    name = "name"
    values = ["amzn2-ami-hvm*", ]
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