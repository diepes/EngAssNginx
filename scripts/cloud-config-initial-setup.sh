#!/bin/bash
# Called from initial cloud-config when ec2 instance created.

cp /opt/gitrepo/scripts/docker.nginx.service /etc/systemd/system/docker.nginx.service
cp /opt/gitrepo/scripts/uvicorn.health-status.service  /etc/systemd/system/uvicorn.health-status.service
cp /opt/gitrepo/scripts/uvicorn.health-status.path  /etc/systemd/system/uvicorn.health-status.path
systemctl daemon-reload

systemctl enable docker.service
systemctl start --no-block, docker.service

systemctl enable docker.nginx.service
systemctl start --no-block docker.nginx.service

cd /opt/gitrepo/scripts
python3 -m pip install -r requirements.txt
systemctl enable uvicorn.health-status.service
systemctl start --no-block uvicorn.health-status.service
#path restart uvicorn on code update
systemctl enable uvicorn.health-status.path
systemctl start --no-block uvicorn.health-status.path

echo "*/5 * * * * root /opt/gitrepo/scripts/cron.sh 2>&1 | /dev/null" > /etc/cron.d/gitrepo

# For Demo and Tracking add instance id to static page.
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"` &&\
     curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id |\
     tee /opt/gitrepo/html/instance-id

# The END.