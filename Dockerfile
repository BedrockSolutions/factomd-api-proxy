FROM openresty/openresty:stretch

COPY confd /etc/confd
COPY modules /home/nginx/modules
COPY entrypoint.sh /home/nginx/entrypoint.sh

ADD https://github.com/kelseyhightower/confd/releases/download/v0.16.0/confd-0.16.0-linux-amd64 /usr/local/bin/confd
#COPY ./bin/confd /usr/local/bin/confd

RUN set -xe && \
  chmod +x /usr/local/bin/confd && \
  groupadd -g 1000 nginx && \
  useradd -r -m -u 1000 -g nginx nginx && \
  ln -fs /home/nginx/default.conf /etc/nginx/conf.d/default.conf && \
  ln -fs /home/nginx/modules /usr/local/openresty/nginx/lua && \
  mkdir /home/nginx/values && \
  chown -R nginx:nginx /usr/local/openresty /home/nginx

WORKDIR /home/nginx

USER nginx

ENTRYPOINT ["./entrypoint.sh"]
