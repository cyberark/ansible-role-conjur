#!/usr/bin/env bash

function main() {
    echo '-----'
    echo '----------'
    echo '---------------'
    echo "Retrieving secrets via Summon in target"
    echo '---------------'
    echo '----------'
    echo '-----'
    RetrieveViaSummon
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
