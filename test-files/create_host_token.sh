#!/usr/bin/env bash

cd /conjurinc/ansible
rm -rf output
mkdir -p output
conjur policy load root policies/root.yml
conjur variable values add ansible/target-password target_secret_password
conjur variable values add ansible/another-target-password another_target_secret_password
conjur variable values add ansible/master-password ansible_master_secret_password
export HFTOKEN=$(conjur hostfactory tokens create --duration-minutes=3 ansible/ansible-factory | jq -r '.[0].token')
echo "${HFTOKEN}" > output/hftoken.txt
