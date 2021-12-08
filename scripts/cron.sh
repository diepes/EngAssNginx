#!/bin/bash
echo "#$(date -Is) $0 cron running" >> /var/log/cron-gitrepo.log

## Git updte gitrepo
cd /opt/gitrepo
git pull | grep -v "Already up to date." >> /var/log/cron-gitrepo.log 



