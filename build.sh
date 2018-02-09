#!/bin/bash -e

rm -rf pkg
mkdir -p pkg pkg/conjur-env

wd=$(cd $(dirname $0); pwd)
cd "$wd"

./conjur-env/build.sh

cp -R ./conjur-env/conjur-env* pkg/conjur-env
cp -R ./configure-conjur-identity pkg
cp -R ./lookup_plugins pkg
cp -R ./library pkg
cp -R ./summon_conjur pkg
cp -R ./CHANGELOG.md pkg
cp -R ./LICENSE.md pkg
cp -R ./requirements.txt pkg

tar -czvf ansible-role-conjur.tar.gz pkg
