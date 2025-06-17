FROM docker.io/pschiffe/borg:latest

ADD  sync-files.sh entrypoint.sh /
RUN chmod +x /sync-files.sh /entrypoint.sh

ENTRYPOINT /entrypoint.sh
