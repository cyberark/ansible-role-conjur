#!/usr/bin/env bash

cd /conjurinc/ansible
rm -rf client-output
mkdir -p client-output
conjur policy load root policies/root.yml
conjur variable values add password mysecretpassword
export HFTOKEN=$(conjur hostfactory tokens create --duration-days=365 ansible-factory | jq -r '.[0].token')
echo $HFTOKEN > client-output/hftoken.txt
