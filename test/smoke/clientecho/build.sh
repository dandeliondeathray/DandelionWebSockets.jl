#!/bin/bash

if ! [ -d test ] && ! [ -d src ]; then
    echo "This must be executed from the root directory of DandelionWebSockets, because of"
    echo "Docker reasons."
    exit 1
fi

docker build \
    -t dandelionwebsockets/smoke_clientecho_server \
    -f test/smoke/clientecho/Dockerfile.server \
    test/smoke/clientecho

docker build \
    -t dandelionwebsockets/smoke_clientecho_client \
    -f test/smoke/clientecho/Dockerfile.client \
    .
