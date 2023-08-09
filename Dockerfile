FROM alpine:3.18.3

RUN \
  apk add --update haproxy inotify-tools && \
  rm -rf /var/cache/apk/*

ADD container-files /

CMD ["/bootstrap.sh"]