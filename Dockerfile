FROM amazonlinux:latest
MAINTAINER Bhavik Kumar <bhavik@depost.pro>

COPY crond /etc/pam.d/crond
RUN chmod 0644 /etc/pam.d/crond

RUN yum update -y
RUN yum install -y python34-pip
RUN yum install -y jq
RUN yum install -y cronie
RUN pip-3.4 install awscli

COPY crontab /var/spool/cron/root
RUN chmod 0644 /var/spool/cron/root

RUN touch /var/log/cron.log
RUN ln -sf /proc/1/fd/1 /var/log/cron.log

COPY reaper.sh /
COPY refresh_leader.sh /
COPY terminate_node.sh /
COPY entry.sh /

RUN chmod +x /reaper.sh
RUN chmod +x /refresh_leader.sh
RUN chmod +x /terminate_node.sh
RUN chmod +x /entry.sh

WORKDIR /

CMD ["/entry.sh"]
