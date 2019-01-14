FROM openresty/openresty:stretch

COPY confd /etc/confd

ADD https://github.com/kelseyhightower/confd/releases/download/v0.16.0/confd-0.16.0-linux-amd64 /usr/local/bin/confd
#COPY ./bin/confd /usr/local/bin/confd

RUN set -xe && \
  groupadd -g 1000 nginx && \
  useradd -r -m -u 1000 -g nginx nginx && \
  chown -R nginx:nginx /usr/local/openresty && \
  chmod +x /usr/local/bin/confd && \
  ln -fs /home/nginx/default.conf /etc/nginx/conf.d/default.conf

WORKDIR /home/nginx

USER nginx

COPY ./entrypoint.sh ./

ENV ALLOW_ORIGIN ""
ENV API_HOSTNAME "localhost"
ENV API_PORT 8088
ENV PORT 8087

ENTRYPOINT ["./entrypoint.sh"]

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]