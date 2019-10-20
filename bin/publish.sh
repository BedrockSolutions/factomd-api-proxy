#!/usr/bin/env bash

TAG_PREFIX='bedrocksolutions/factomd-api-proxy'

VERSION=$(docker run --rm -v ${PWD}:/workdir mikefarah/yq yq r ./defaults.yaml version)

TAG="${TAG_PREFIX}:v${VERSION}"

docker build -t ${TAG} .

docker push ${TAG}
