#!/bin/bash -e
set -x

function finish {
  echo 'Removing test environment'
  echo '---'
  docker-compose down -v
  rm -rf inventory.tmp
}
trap finish EXIT
finish

# normalises project name by filtering non alphanumeric characters and transforming to lowercase
declare -x COMPOSE_PROJECT_NAME=$(echo ${BUILD_TAG:-"ansible-role-testing"} | sed -e 's/[^[:alnum:]]//g' | tr '[:upper:]' '[:lower:]')

declare -x CUSTOM_TARGET_CONJUR_AUTHN_API_KEY=''
declare -x CUSTOM_TARGET_CONJUR_V4_AUTHN_API_KEY=''
declare -x ANSIBLE_CONJUR_AUTHN_API_KEY=''
declare -x ANSIBLE_CONJUR_V4_AUTHN_API_KEY=''
declare -x CLI_CONJUR_AUTHN_API_KEY=''
declare -x CONJUR_V4_SSL_CERTIFICATE=''
declare -x CONJUR_V4_APPLIANCE_URL='https://cuke-master/api'
declare cli_cid=''
declare conjur_cid=''
declare ansible_cid=''

function api_key_for {
  local role_id=$1
  if [ ! -z "$role_id" ]
  then
    docker exec ${conjur_cid} rails r "print Credentials['${role_id}'].api_key"
  else
    echo ERROR: api_key_for called with no argument 1>&2
    exit 1
  fi
}

function api_key_for_v4 {
  local role_id=$1
  if [ ! -z "$role_id" ]
  then
    docker-compose exec -T cuke-master conjur host rotate_api_key --host $role_id
  else
    echo ERROR: api_key_for called with no argument 1>&2
    exit 1
  fi
}

function hf_token {
  echo $(docker exec ${cli_cid} conjur hostfactory tokens create --duration-minutes=5 ansible/ansible-factory | jq -r '.[0].token')
}

function hf_token_v4 {
  echo $(docker-compose exec -T cuke-master conjur hostfactory tokens create --duration-minutes=5 ansible/ansible-factory | jq -r '.[0].token')
}

function setup_conjurs {
  setup_conjur
  setup_conjur_v4
}

function setup_conjur {
  echo "---- setting up conjur ----"

  docker exec ${cli_cid} bash -c '
# run policy
conjur policy load root /policy/root.yml
# set secret values
conjur variable values add ansible/target-password target_secret_password
conjur variable values add ansible/another-target-password another_target_secret_password
conjur variable values add ansible/master-password ansible_master_secret_password
'
}

function setup_conjur_v4 {
echo "---- setting up conjur v4 ----"

  docker-compose exec -T cuke-master /wait_for_v4.sh
  docker-compose exec -T cuke-master bash -c '
# login
conjur authn login -u admin -p secret
# run policy
conjur policy load --as-group security_admin /policy/root.yml
# set secret values
conjur variable values add ansible/target-password target_secret_password
conjur variable values add ansible/another-target-password another_target_secret_password
conjur variable values add ansible/master-password ansible_master_secret_password
'
}

function run_test_cases {
  for test_case in `ls test_cases_v4`; do
    teardown_and_setup
    run_test_case_v4 $test_case
  done

  for test_case in `ls test_cases`; do
    teardown_and_setup
    run_test_case $test_case
  done
}

function run_test_case {
  echo "---- testing ${test_case} ----"
  local test_case=$1
  if [ ! -z "$test_case" ]
  then
    docker exec ${ansible_cid} env HFTOKEN=$(hf_token) bash -c "
      cd tests
      ansible-playbook test_cases/${test_case}/playbook.yml
    "
    docker exec ${ansible_cid} bash -c "
      cd tests
      py.test --junitxml=./junit/${test_case} --connection docker -v test_cases/${test_case}/tests/test_default.py
    "
  else
    echo ERROR: run_test called with no argument 1>&2
    exit 1
  fi
}

function run_test_case_v4 {
  echo "---- testing ${test_case} ----"
  local test_case=$1
  if [ ! -z "$test_case" ]
  then
    docker exec ${ansible_cid} env HFTOKEN="$(hf_token_v4)" CONJUR_APPLIANCE_URL="$CONJUR_V4_APPLIANCE_URL" CONJUR_MAJOR_VERSION="4" CONJUR_AUTHN_API_KEY="$ANSIBLE_CONJUR_V4_AUTHN_API_KEY" CONJUR_SSL_CERTIFICATE="$CONJUR_V4_SSL_CERTIFICATE" bash -c "
      cd tests
      ansible-playbook test_cases_v4/${test_case}/playbook.yml
    "
    docker exec ${ansible_cid} env CONJUR_APPLIANCE_URL="$CONJUR_V4_APPLIANCE_URL" CONJUR_MAJOR_VERSION="4" CONJUR_AUTHN_API_KEY="$ANSIBLE_CONJUR_V4_AUTHN_API_KEY)" CONJUR_SSL_CERTIFICATE="$CONJUR_V4_SSL_CERTIFICATE" bash -c "
      cd tests
      py.test --junitxml=./junit/v4_${test_case} --connection docker -v test_cases_v4/${test_case}/tests/test_default.py
    "
  else
    echo ERROR: run_test called with no argument 1>&2
    exit 1
  fi
}

function teardown_and_setup {
  docker-compose up -d --force-recreate --scale test_app=2 test_app
}

function wait_for_server {
  docker exec ${cli_cid} bash -c '
    for i in $(seq 20); do
      curl -o /dev/null -fs -X OPTIONS ${CONJUR_APPLIANCE_URL} > /dev/null && echo "server is up" && break
      echo "."
      sleep 2
    done
  '
}

function fetch_ssl_cert {
  docker exec $(docker-compose ps -q conjur-proxy-nginx) cat cert.crt > conjur.pem
}

function fetch_ssl_cert_v4 {
  docker-compose exec -T cuke-master cat /opt/conjur/etc/ssl/ca.pem > conjur_v4.pem
}

function generate_inventory {
  # uses .j2 template to generate inventory prepended with COMPOSE_PROJECT_NAME
  docker exec $(docker-compose ps -q ansible) bash -c '
    cd tests
    ansible-playbook -i -, inventory-playbook.yml
  '
}

function main() {
  docker-compose up -d --build
  generate_inventory

  conjur_cid=$(docker-compose ps -q conjur)
  cli_cid=$(docker-compose ps -q conjur_cli)
  fetch_ssl_cert
  fetch_ssl_cert_v4
  wait_for_server

  CLI_CONJUR_AUTHN_API_KEY=$(api_key_for 'cucumber:user:admin')
  docker-compose up -d conjur_cli
  cli_cid=$(docker-compose ps -q conjur_cli)
  setup_conjurs

  CUSTOM_TARGET_CONJUR_AUTHN_API_KEY=$(api_key_for 'cucumber:host:ansible/ansible-custom-target')
  CUSTOM_TARGET_CONJUR_V4_AUTHN_API_KEY=$(api_key_for_v4 'ansible/ansible-custom-target')
  ANSIBLE_CONJUR_AUTHN_API_KEY=$(api_key_for 'cucumber:host:ansible/ansible-master')
  ANSIBLE_CONJUR_V4_AUTHN_API_KEY=$(api_key_for_v4 'ansible/ansible-master')
  CONJUR_V4_SSL_CERTIFICATE="$(cat conjur_v4.pem)"
  docker-compose up -d ansible
  ansible_cid=$(docker-compose ps -q ansible)

  run_test_cases
}

main
