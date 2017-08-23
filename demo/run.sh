#!/usr/bin/env bash

function finish {
  echo 'Removing demo environment'
  echo '-----'
  docker-compose down -v
}
trap finish EXIT

function main() {
  echo '-----'
  echo '----------'
  echo '---------------'
  echo "Starting Ansible demo for Conjur"
  echo '---------------'
  echo '----------'
  echo '-----'

  createDemoEnvironment
  waitForServer
  createHostFactoryToken
  runAnsible
  retrieveSecretInTarget
}

function createDemoEnvironment() {
  echo "Creating demo environment"
  echo '-----'

  docker-compose build --pull target
  docker-compose pull postgres conjur client
  docker-compose up -d client postgres conjur target

  echo '-----'
}

function waitForServer() {
  echo 'Waiting for conjur server to be healthy'
  echo '-----'

  # TODO: remove this once we have HEALTHCHECK in place
  docker-compose run \
    --entrypoint bash \
    client \
    /conjurinc/ansible/wait_for_server.sh

  echo '-----'
}

function createHostFactoryToken() {
  echo "Creating Conjur host factory token"
  echo '-----'

  # get the api key from conjur for login into Conjur
  api_key=$(docker-compose exec -T conjur rails r "print Credentials['cucumber:user:admin'].api_key")

  docker-compose run \
    -e CONJUR_AUTHN_API_KEY=${api_key} \
    --entrypoint bash \
    client \
    /conjurinc/ansible/create_host_token.sh

  echo '-----'
}

function runAnsible() {
  echo "Running Ansible playbook"
  echo '-----'

  export HFTOKEN=$(<client-output/hftoken.txt)

  ansible-playbook demo.yml

  echo '-----'
}

function retrieveSecretInTarget() {
  echo "Fetching secret in target container"
  echo '-----'

  docker exec ansible-target bash -c "echo Conjur identity is: && conjur authn whoami && echo && echo Conjur secret is: \
    && conjur variable value password && echo"

  echo '-----'

  docker exec -i ansible-target bash < summon.sh
}

main
