#!/usr/bin/env bash

function finish {
    echo "Cleaning up..."
    kill $CONJUR_AUTHN_TOKEN_FILE_PID
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
    InstallSummon
    SetMachineIdentityEnv
    RetrieveViaSummon
}

function InstallSummon() {
    echo "Summon & summon-conjur"
    echo '-----'
    mkdir -p /usr/local/lib/summon
    echo "Downloading & installing summon at /usr/local/lib/summon"
    wget -qO- https://github.com/cyberark/summon/releases/download/v0.6.5/summon-linux-amd64.tar.gz | tar xvz -C /usr/local/bin
    echo "Downloading & installing summon-conjur at /usr/local/bin"
    wget -qO- https://github.com/cyberark/summon-conjur/releases/download/v0.3.0/summon-conjur-linux-amd64.tar.gz | tar xvz -C /usr/local/lib/summon
    echo '-----'
}

function SetMachineIdentityEnv() {
    echo "Setting environment variables from machine identity files"
    echo '-----'
    export CONJUR_IDENTITY_PATH=/etc/conjur.conf
    echo "set CONJUR_ACCOUNT, CONJUR_APPLIANCE_URL, CONJUR_NETRC_PATH from $CONJUR_IDENTITY_PATH"
    export CONJUR_ACCOUNT=$(awk '/account:/ {print $2}' $CONJUR_IDENTITY_PATH)
    export CONJUR_APPLIANCE_URL=$(awk '/appliance_url:/ {print $2}' $CONJUR_IDENTITY_PATH)
    CONJUR_NETRC_PATH=$(awk '/netrc_path:/ {print $2}' $CONJUR_IDENTITY_PATH)
    : ${CONJUR_NETRC_PATH:="/etc/conjur.identity"}
    echo '-----'

# Login Credentials
#    echo "set CONJUR_AUTHN_LOGIN, CONJUR_AUTHN_API_KEY from $CONJUR_NETRC_PATH"
#    export CONJUR_AUTHN_LOGIN=$(awk -v CONJUR_APPLIANCE_URL=$CONJUR_APPLIANCE_URL '$0 ~ CONJUR_APPLIANCE_URL {f=1} f && /login/ {print $2;f=0}' $CONJUR_NETRC_PATH)
#    export CONJUR_AUTHN_API_KEY=$(awk -v CONJUR_APPLIANCE_URL=$CONJUR_APPLIANCE_URL '$0 ~ CONJUR_APPLIANCE_URL {f=1} f && /password/ {print $2;f=0}' $CONJUR_NETRC_PATH)
#    echo '-----'

# Token File Credentials
    echo "set CONJUR_AUTHN_TOKEN_FILE written to by conjur-cli"
    while true; do echo $(conjur authn authenticate) > /tmp/CONJUR_AUTHN_TOKEN_FILE ; sleep 2; done &
    export CONJUR_AUTHN_TOKEN_FILE_PID=$!
    export CONJUR_AUTHN_TOKEN_FILE=/tmp/CONJUR_AUTHN_TOKEN_FILE
    echo '-----'
}

function RetrieveViaSummon() {
    echo '-----'
    echo "Create secrets.yml"
    echo 'SUMMON_RETRIEVED_PASSWORD: !var target-password' > secrets.yml
    cat secrets.yml
    echo '-----'
    echo "Retrieving password via summon"
    echo '-----'
    echo ">> summon bash -c 'echo \"The value of the summon retrieved password is: $SUMMON_RETRIEVED_PASSWORD\"'"
    summon bash -c 'echo "The value of the summon retrieved password is: $SUMMON_RETRIEVED_PASSWORD"'
    echo '-----'
}

main
