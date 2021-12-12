# Deploy ec2 server in ASG, to restart on failure.
resource "aws_launch_template" "front-end" {
  name_prefix                          = "${var.prefix}-tf-01"
  image_id                             = data.aws_ami.amazon-linux-2.id
  instance_type                        = "t2.micro"
  instance_initiated_shutdown_behavior = "terminate"
  # spot_price    = "0.045"
  network_interfaces {
    associate_public_ip_address = false
    security_groups = flatten([
      module.security_group.security_group_id,
    ])
  }
  iam_instance_profile {
    name = aws_iam_instance_profile.ssm-profile.name
  }
  #key_name = no ssh access.
  user_data = base64encode(templatefile("ec2-userdata.yaml",
    { HOSTNAME  = "${var.prefix}-web-server",
      GITREPO   = var.gitrepo,
      GITBRANCH = var.gitbranch,
    }
    )
  )
  tags = var.tags
  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags,
      { Name = "${var.prefix}-web-server" },
    )
  }
  #Prevent error: 
  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_autoscaling_group" "front-end" {
  name = "${var.prefix}-tf-asg"
  launch_template {
    id = aws_launch_template.front-end.id
    #version = aws_launch_template.front-end.latest_version
    version = "$Latest"
  }
  vpc_zone_identifier       = module.vpc.private_subnets
  desired_capacity          = 1
  min_size                  = 1
  max_size                  = 2
  force_delete              = true
  health_check_grace_period = 120
  health_check_type         = "ELB"
  #
  target_group_arns = [aws_lb_target_group.www.arn, aws_lb_target_group.api.arn]
  #
  instance_refresh {
    strategy = "Rolling"
    preferences {
      # Still downtime, for 1 instance, stop then start :(
      min_healthy_percentage = 90
    }
    triggers = ["tag"]
  }
}


data "aws_ami" "amazon-linux-2" {
  # login user ec2-user@
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*", ]
  }
  filter {
    name   = "owner-alias"
    values = ["amazon", ]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

