
# Note: set aws secrets with 
#       $ export AWS_ACCESS_KEY_ID= 
#       $ export AWS_SECRET_ACCESS_KEY=
#
aws_region   = "ap-southeast-2"

# Install setup scripts and ./html content
gitrepo      = "https://github.com/diepes/EngAssNginx.git"
#gitbranch    = "main"
gitbranch = "test"

# Prefix for aws tags
# Try to keep it short, e.g. nameprefix allows max 6 char.
prefix       = "ngx"

# Key for ssh access to instance's
pub_key_name = "my-ssh-pub-key"
pub_key_path = "~/.ssh/id_rsa.pub"

tags = {
    Project = "Nginx - Webserver + Monitor"
    Env     = "Test"
    Owner   = "P.Smit"
    }
