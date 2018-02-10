#!/bin/bash -e

echo "Build 'conjur-fetch'"

cd $(dirname $0)
rm -rf ./conjur-fetch*
# http://blog.wrouesnel.com/articles/Totally%20static%20Go%20builds/
docker-compose build
docker-compose run --rm conjur-fetch-builder /pkg/build_binaries.sh
