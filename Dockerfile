FROM openresty/openresty:stretch

RUN set -xe && \
  apt-get update && \
  apt-get --no-install-recommends -y install inotify-tools && \
  groupadd -g 1000 app && \
  useradd -r -m -u 1000 -g app app && \
  ln -fs /home/app/default.conf /etc/nginx/conf.d/default.conf && \
  ln -fs /home/app/modules /usr/local/openresty/nginx/lua

WORKDIR /home/app

ADD https://github.com/kelseyhightower/confd/releases/download/v0.16.0/confd-0.16.0-linux-amd64 /usr/local/bin/confd
#COPY ./bin/confd /usr/local/bin/confd

COPY confd ./confd
COPY modules ./modules
COPY defaults.yaml ./defaults.yaml
COPY entrypoint.sh ./entrypoint.sh

RUN \
  mkdir ./ssl ./values && \
  chown -R app:app /usr/local/openresty /home/app && \
  chmod +x /usr/local/bin/confd

USER app

ENTRYPOINT ["./entrypoint.sh"]
