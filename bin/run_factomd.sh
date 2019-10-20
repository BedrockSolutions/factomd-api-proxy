#!/usr/bin/env bash

docker stop factomd

docker rm factomd

docker run -d --name factomd \
  -p 8088:8088 -p 8090:8090 -p 8108:8108 \
  -v $(pwd)/scratch/factomd/config:/app/config \
  -v $(pwd)/scratch/factomd/config:/app/config \
  bedrocksolutions/factomd:FD-689_test0

docker logs -f factomd
