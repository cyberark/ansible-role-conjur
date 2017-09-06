#!/usr/bin/env bash

cd /conjurinc/ansible
mkdir -p output
rm -f output/conjur.pem
rm -f /root/conjur-cucumber.pem
rm -f /root/.conjurrc
echo "yes" | conjur init -u "${CONJUR_PROXY_URL}" -a "${CONJUR_ACCOUNT}"
cp /root/conjur-cucumber.pem output/conjur.pem
