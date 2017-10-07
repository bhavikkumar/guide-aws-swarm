FROM amazonlinux:latest
MAINTAINER Bhavik Kumar <bhavik@depost.pro>

RUN yum update -y
RUN yum install -y python34-pip
RUN yum install -y jq
RUN yum install -y cronie
RUN pip-3.4 install awscli

COPY crontab /etc/cron.d/guide-aws-swarm
RUN chmod 0644 /etc/cron.d/guide-aws-swarm

COPY reaper.sh /
COPY refresh_leader.sh /
COPY terminate_node.sh /

RUN chmod +x /reaper.sh
RUN chmod +x /refresh_leader.sh
RUN chmod +x /terminate_node.sh

WORKDIR /

CMD ["crond", "-n", "-s", "-p"]
