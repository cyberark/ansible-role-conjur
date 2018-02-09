#!/bin/bash -e

echo "Build 'conjur-env'"

wd=$(cd $(dirname $0); pwd)
rm -rf ${wd}/conjur-env*
# http://blog.wrouesnel.com/articles/Totally%20static%20Go%20builds/
docker run --rm \
 -v "${wd}":/go/src/conjur-env \
 -w /go/src/conjur-env \
 -e CGO_ENABLED=0 \
 golang:1.8-alpine3.5 \
 ./build_binaries.sh
