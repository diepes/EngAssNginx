#!/bin/bash
echo "#$(date -Is} $0 cron running" >> /var/log/gitrepo-cron.log

## Git updte gitrepo
cd /opt/gitrepo
git pull
git status


# The End.



