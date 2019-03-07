#!/usr/bin/env bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

cd ${SCRIPT_DIR}/..

docker stop proxy

docker rm proxy

docker run -d -p 443:8443 -v /Users/jay/code/factomd-api-proxy/scratch:/home/app/values --name proxy factomd-api-proxy
