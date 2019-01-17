#!/usr/bin/env sh

set -e

confd &

sleep 2

exec /usr/bin/openresty -g 'daemon off;'
