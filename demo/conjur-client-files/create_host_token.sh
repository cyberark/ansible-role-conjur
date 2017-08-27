#!/usr/bin/env bash

cd /conjurinc/ansible
rm -rf output
mkdir -p output
conjur policy load root policies/root.yml
conjur variable values add ansible/target-password targetSecretPassword
conjur variable values add ansible/master-password ansibleMasterSecretPassword
export HFTOKEN=$(conjur hostfactory tokens create --duration-days=365 ansible/ansible-factory | jq -r '.[0].token')
echo "${HFTOKEN}" > output/hftoken.txt
