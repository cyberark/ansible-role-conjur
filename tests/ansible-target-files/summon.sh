#!/usr/bin/env bash

function finish {
    echo "Cleaning up..."
    kill ${CONJUR_AUTHN_TOKEN_FILE_PID}
    echo "All done."
}
trap finish EXIT

function main() {
    echo '-----'
    echo '----------'
    echo '---------------'
    echo "Retrieving secrets via Summon in target"
    echo '---------------'
    echo '----------'
    echo '-----'
    SetMachineIdentityEnv
    RetrieveViaSummon
}

function SetMachineIdentityEnv() {
    echo "Setting environment variables from machine identity files"
    echo '-----'
    export CONJUR_IDENTITY_PATH=/etc/conjur.conf
    echo "set CONJUR_ACCOUNT, CONJUR_APPLIANCE_URL, CONJUR_NETRC_PATH from $CONJUR_IDENTITY_PATH"
    export CONJUR_ACCOUNT=$(awk '/account:/ {print $2}' ${CONJUR_IDENTITY_PATH})
    export CONJUR_APPLIANCE_URL=$(awk '/appliance_url:/ {print $2}' ${CONJUR_IDENTITY_PATH})
    CONJUR_NETRC_PATH=$(awk '/netrc_path:/ {print $2}' ${CONJUR_IDENTITY_PATH})
    : ${CONJUR_NETRC_PATH:="/etc/conjur.identity"}
    echo '-----'

    # Token File Credentials
    echo "set CONJUR_AUTHN_TOKEN_FILE written to by conjur-cli"
    while true; do echo "$(conjur authn authenticate)" > /tmp/CONJUR_AUTHN_TOKEN_FILE ; sleep 2; done &
    export CONJUR_AUTHN_TOKEN_FILE_PID=$!
    export CONJUR_AUTHN_TOKEN_FILE=/tmp/CONJUR_AUTHN_TOKEN_FILE
    echo '-----'
}

function RetrieveViaSummon() {
    echo '-----'
    echo "Create secrets.yml"
    echo 'SUMMON_RETRIEVED_PASSWORD: !var ansible/target-password' > secrets.yml
    cat secrets.yml
    echo '-----'
    echo "Retrieving password via summon"
    echo '-----'
    summon bash -c 'echo "The value of the summon retrieved password is: $SUMMON_RETRIEVED_PASSWORD"'
    echo '-----'
}

main
