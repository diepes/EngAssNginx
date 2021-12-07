
# output "_03_ssh_login" {
#     value = "# ssh ec2-user@${aws_instance.server.public_ip}"
# }
# output "curl_mon_api" {
#     value = "# curl -is http://${aws_instance.server.public_ip}/logs\n"
# }
output "curl_website_lb_url" {
    value = "# curl -is http://${aws_lb.server.dns_name}/\n"
}

output "_01_loadbalancer" {
    value = aws_lb.server.dns_name
}
output "_02_aws_region" {
  value = var.aws_region
}