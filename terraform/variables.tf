variable "pub_key_path" {
  type        = string
  description = "path to public key to use for new instance setup."
}
variable "pub_key_name" {
  type        = string
  description = "name of key in aws."
}

variable "gitrepo" {
  type        = string
  description = "Git repo to be cloned into /opt/gitrepo , contains ./scripts and ./html"
}
variable "gitbranch" {
  type        = string
  description = "Used in initial tf deployment by ec2-userdata.yml to set git branch."
}
variable "aws_region" {
  type = string
}

variable "prefix" {
  type        = string
  description = "prefix value used to make names uniq"
}

variable "tags" {
  type        = map(string)
  description = "Tags for aws resources."
}