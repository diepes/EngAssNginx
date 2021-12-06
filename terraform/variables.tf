variable pub_key_path {
    type    = string
    default = "~/.ssh/id_rsa.pub" 
    description = "path to public key to use for new instance setup."
}

variable "aws_region" {
  type = string
  default = "ap-southeast-2"
  #default = "us-west-2"
}

variable "prefix" {
    type    = string
    default = "nginx"
    description = "prefix value used to make names uniq"
}