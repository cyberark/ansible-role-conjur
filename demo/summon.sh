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
    RetrieveViaSummon
}

function InstallSummon() {
    echo "Summon & summon-conjur"
    echo '-----'
    mkdir -p /usr/local/lib/summon
    echo "Downloading & installing summon at /usr/local/bin"
    wget -qO- https://github.com/cyberark/summon/releases/download/v0.6.5/summon-linux-amd64.tar.gz | tar xvz -C /usr/local/bin
    echo "Downloading & installing summon-conjur at /usr/local/lib/summon"
#   already presented in the directory (beta)
    echo '-----'

}

function RetrieveViaSummon() {
    echo '-----'
    echo "Create secrets.yml"
    echo 'SUMMON_RETRIEVED_PASSWORD: !var password' > secrets.yml
    cat secrets.yml
    echo '-----'
    echo "Retrieving password via summon"
    echo '-----'
    echo ">> summon bash -c 'echo \"The value of the summon retrieved password is: $SUMMON_RETRIEVED_PASSWORD\"'"
    summon bash -c 'echo "The value of the summon retrieved password is: $SUMMON_RETRIEVED_PASSWORD"'
    echo '-----'
}

main
