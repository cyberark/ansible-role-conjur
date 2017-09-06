#!/usr/bin/env bash

export CONJUR_IDENTITY_PATH=/etc/conjur.conf
export CONJUR_ACCOUNT=$(awk '/account:/ {print $2}' ${CONJUR_IDENTITY_PATH})
export CONJUR_APPLIANCE_URL=$(awk '/appliance_url:/ {print $2}' ${CONJUR_IDENTITY_PATH})
CONJUR_NETRC_PATH=$(awk '/netrc_path:/ {print $2}' ${CONJUR_IDENTITY_PATH}) : ${CONJUR_NETRC_PATH:="/etc/conjur.identity"}
while true; do echo "$(conjur authn authenticate)" > /tmp/CONJUR_AUTHN_TOKEN_FILE ; sleep 2; done & export CONJUR_AUTHN_TOKEN_FILE_PID=$!
export CONJUR_AUTHN_TOKEN_FILE=/tmp/CONJUR_AUTHN_TOKEN_FILE
echo 'SUMMON_RETRIEVED_PASSWORD: !var ansible/target-password' > secrets.yml
summon bash -c 'echo "$SUMMON_RETRIEVED_PASSWORD" > secret.txt'
