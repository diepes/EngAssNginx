# # Leave for now, no requirement for HA, rolling updates or SSL+Cert
# # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group

resource "aws_security_group" "lb" {
  name        = "${var.prefix}-lb-pubic"
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
    Name = "${var.prefix}-lb-public"
  }
}
resource "aws_lb" "server" {
  name                       = "${var.prefix}-server"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.lb.id]
  subnets                    = module.vpc.public_subnets
  enable_deletion_protection = false
  #tags = var.lb_tags
  depends_on = [
    aws_security_group.lb,
    aws_lb_target_group.www,
    aws_lb_target_group.api,
  ]
}
resource "aws_lb_listener" "server" {
  load_balancer_arn = aws_lb.server.arn
  port              = 80
  protocol          = "HTTP"
  #port              = "443"
  #protocol          = "HTTPS"
  #ssl_policy        = "ELBSecurityPolicy-2016-08"
  #certificate_arn   = aws_acm_certificate.front_end.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.www.arn
  }
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.server.arn
  priority     = 100
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}
resource "aws_lb_target_group" "www" {
  name     = "${var.prefix}-tg-www"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}
resource "aws_lb_target_group" "api" {
  name     = "${var.prefix}-tg-api"
  port     = 82
  protocol = "HTTP"
  path     = "/api/"
  vpc_id   = module.vpc.vpc_id
}

# resource "aws_lb_listener_certificate" "front_end" {
#   listener_arn    = aws_lb_listener.front_end.arn
#   certificate_arn = aws_acm_certificate.front_end.arn
# }
