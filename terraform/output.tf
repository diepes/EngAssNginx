
output "ssh_login" {
    value = "# ssh ec2-user@${aws_eip.website.public_ip}"
}
output "curl_view" {
    value = "# curl -is http://${aws_eip.website.public_ip}"
}