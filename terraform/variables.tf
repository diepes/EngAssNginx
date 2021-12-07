variable pub_key_path {
    type    = string
    default = "~/.ssh/id_rsa.pub" 
    description = "path to public key to use for new instance setup."
}

variable gitrepo {
  type        = string
  default     = "https://github.com/diepes/EngAssNginx.git"
  description = "Git repo to be cloned into /opt/gitrepo , contains ./scripts and ./html"
}
variable gitbranch {
  type    = string
  default = "test"
  description = "Used in initial tf deployment by ec2-userdata.yml to set git branch."
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