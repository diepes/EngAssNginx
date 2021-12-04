
output "ssh_login" {
    value = "# ssh ec2-user@${aws_eip.website.public_ip}"
}