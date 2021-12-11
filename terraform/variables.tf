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