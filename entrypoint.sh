#!/usr/bin/env sh

set -e

confd -onetime -backend env

exec "$@"