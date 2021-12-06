# # Leave for now, no requirement for HA, rolling updates or SSL+Cert
# # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group

# resource "aws_placement_group" "cluster" {
#   name     = "${var.prefix}-cluster"
#   strategy = "cluster"
# }

# resource "aws_autoscaling_group" "nginx" {
#   availability_zones = [ var.region ]
#   desired_capacity   = 1
#   max_size           = 1
#   min_size           = 1

#   launch_template {
#     id      = aws_launch_template.nginx.id
#     version = "$Latest"
#   }
# }

# resource "aws_acm_certificate" "front_end" {
#   # ...
# }
resource "aws_security_group" "lb" {
  name        = "allow_web"
  description = "Allow http/https inbound traffic"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description      = "TLS from WWW"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
  }
  ingress {
    description      = "HTTP from WWW"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}
resource "aws_lb" "front_end" {
  name          = "front-end"
  internal      = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets       = module.vpc.public_subnets
  enable_deletion_protection = false
  #tags = var.lb_tags
}
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.front_end.arn
  port              = 80
  protocol          = "HTTP"
  #port              = "443"
  #protocol          = "HTTPS"
  #ssl_policy        = "ELBSecurityPolicy-2016-08"
  #certificate_arn   = aws_acm_certificate.front_end.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front_end.arn
  }
}
resource "aws_lb_target_group" "front_end" {
  name     = "${var.prefix}-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}
resource "aws_lb_target_group_attachment" "front_end" {
  target_group_arn = aws_lb_target_group.front_end.arn
  target_id        = aws_instance.server.id
  port             = 8080
}
# resource "aws_lb_listener_certificate" "front_end" {
#   listener_arn    = aws_lb_listener.front_end.arn
#   certificate_arn = aws_acm_certificate.front_end.arn
# }
