#!/usr/bin/env bash

NAMESPACE='bedrocksolutions'
IMAGE_NAME='factomd-api-proxy'
TAG='latest'

set -xe

docker push ${NAMESPACE}/${IMAGE_NAME}:${TAG}
