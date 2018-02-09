#!/bin/bash -e

echo "Build 'conjur-env'"

cd $(dirname $0)
rm -rf ./conjur-env*
# http://blog.wrouesnel.com/articles/Totally%20static%20Go%20builds/
docker-compose build
docker-compose run --rm conjur-env-builder /pkg/build_binaries.sh
