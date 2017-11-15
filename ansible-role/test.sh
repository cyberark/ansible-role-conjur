#!/bin/bash -e
set -x

function finish {
  echo 'Removing test environment'
  echo '---'
  docker-compose down -v
}
trap finish EXIT

declare _api_key=''
declare cli_cid=''
declare conjur_cid=''
declare ansible_cid=''

function api_key {
  if [ -z ${_api_key} ]
  then
    _api_key=$(docker exec ${conjur_cid} rails r "print Credentials['cucumber:user:admin'].api_key")
  fi
  echo ${_api_key}
}

function hf_token {
  echo $(docker exec ${cli_cid} env CONJUR_AUTHN_API_KEY=$(api_key) conjur hostfactory tokens create --duration-minutes=5 ansible/ansible-factory | jq -r '.[0].token')
}

function setup_conjur {
  echo "---- setting up conjur ----"
  # run policy
  docker exec ${cli_cid} env CONJUR_AUTHN_API_KEY=$(api_key) conjur policy load root /policy/root.yml

  # set secret values
  local set_secrets_commands=$(cat <<-EOF
conjur variable values add ansible/target-password target_secret_password
conjur variable values add ansible/another-target-password another_target_secret_password
conjur variable values add ansible/master-password ansible_master_secret_password
EOF
)
  docker exec ${cli_cid} env CONJUR_AUTHN_API_KEY=$(api_key) bash -c "$set_secrets_commands"
}

function run_test_cases {
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
    docker exec ${ansible_cid} env HFTOKEN=$(hf_token) bash -c "cd ansible-role && ansible-playbook test_cases/${test_case}/playbook.yml"
    docker exec ${ansible_cid} bash -c "cd ansible-role && py.test --junitxml=./junit/${test_case} --connection docker -v test_cases/${test_case}/tests/test_default.py"
  else
    echo ERROR: run_test called with no argument 1>&2
    exit 1
  fi
}

function teardown_and_setup {
  docker-compose up -d --force-recreate --scale test_app=2 test_app
}

wait_for_server_command=$(cat <<-EOF
for i in $(seq 20); do
  curl -o /dev/null -fs -X OPTIONS \${CONJUR_APPLIANCE_URL} > /dev/null && echo "server is up" && break
  echo "."
  sleep 2
done
EOF
)
function wait_for_server {
  docker exec ${cli_cid} bash -c "$wait_for_server_command"
}

function main() {
  docker-compose down
  docker-compose up -d --build
  cli_cid=$(docker-compose ps -q conjur_cli)
  conjur_cid=$(docker-compose ps -q conjur)
  ansible_cid=$(docker-compose ps -q ansible)
  wait_for_server
  api_key
  setup_conjur
  run_test_cases
}

main
