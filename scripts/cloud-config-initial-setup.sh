#!/bin/bash
# Called from initial cloud-config when ec2 instance created.

cp /opt/gitrepo/scripts/docker.nginx.service /etc/systemd/system/docker.nginx.service
systemctl daemon-reload

systemctl enable docker.service
systemctl,start --no-block, docker.service

systemctl enable docker.nginx.service
systemctl start --no-block docker.nginx.service


echo "*/5 * * * * root /opt/gitrepo/scripts/cron.sh 2>&1 | /dev/null" > /etc/cron.d/gitrepo

# The END.