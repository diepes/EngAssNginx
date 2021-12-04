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