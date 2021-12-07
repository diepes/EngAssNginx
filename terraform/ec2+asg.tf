# Deploy ec2 server in ASG, to restart on failure.
resource "aws_launch_template" "front-end" {
  name_prefix   = "${var.prefix}-tf-01"
  image_id      = data.aws_ami.amazon-linux-2.id
  instance_type = "t2.micro"
  instance_initiated_shutdown_behavior = "terminate"
  # spot_price    = "0.045"
  # iam_instance_profile { name = "" } 
  #associate_public_ip_address = true
  vpc_security_group_ids = flatten([
                              module.security_group.security_group_id, 
                            ])
  key_name  = aws_key_pair.ssh_key.key_name
  user_data = base64encode(templatefile("ec2-userdata.yaml",
                                         { HOSTNAME = "${var.prefix}-web-server",
                                           GITREPO = var.gitrepo,
                                           GITBRANCH = var.gitbranch,
                                          }
                                        )
                          )
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.prefix}-web-server"
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_autoscaling_group" "front-end" {
  name                 = "${var.prefix}-tf-asg"
  launch_template {
    id      = aws_launch_template.front-end.id
    version = "$Latest"
  }
  vpc_zone_identifier  = module.vpc.public_subnets
  desired_capacity     = 1
  min_size             = 1
  max_size             = 1
  force_delete         = true
  health_check_grace_period = 300
  health_check_type         = "ELB"
  lifecycle { create_before_destroy = true }
}


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

  name        = "${var.prefix}-server"
  description = "Security group for web EC2 instance"
  vpc_id      = module.vpc.vpc_id

  # https://github.com/terraform-aws-modules/terraform-aws-security-group/blob/master/rules.tf
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "all-icmp", "ssh-tcp"]  # Should be internal, demo api, and ssh 
  ingress_with_cidr_blocks = [
      {
        from_port   = 8080
        to_port     = 8080
        protocol    = "tcp"
        description = "http-lb-access"
        cidr_blocks = "10.0.0.0/8"
      },
    ]
  egress_rules        = ["all-all"]
}