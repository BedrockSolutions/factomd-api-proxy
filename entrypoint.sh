#!/usr/bin/env sh

set -e

confd -onetime -sync-only -config-file "/home/app/confd/confd.toml"

{
  while true; do
    inotifywait -m ~/values -e create -e modify -e delete -e move -r |
      while read path action file; do
        echo "inotifywait: ${action} event on ${path}${file}"
        confd -onetime -config-file "/home/app/confd/confd.toml"
      done
  done
} &

exec /usr/bin/openresty -g 'daemon off;'
