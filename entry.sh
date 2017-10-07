#!/bin/bash
# export all environment variables to use in cron
env | sed 's/^\(.*\)$/export \1/g' > /root/envs.sh
chmod +x /root/envs.sh

crond && tail -f /var/log/cron.log
