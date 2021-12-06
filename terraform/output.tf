
output "ssh_login" {
    value = "# ssh ec2-user@${aws_instance.server.public_ip}"
}
output "curl_view" {
    value = "# curl -is http://${aws_lb.front_end.dns_name}/"
}

output "loadbalancer" {
    value = aws_lb.front_end.dns_name
}