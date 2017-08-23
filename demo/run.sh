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
  conjurizeTargetContainer
  RetrieveSecretInTarget
  RetrieveSecretWithPlugin
}

function createDemoEnvironment() {
  echo "Creating demo environment"
  echo '-----'

  docker-compose build --pull target lookup-target
  docker-compose pull postgres conjur client
  docker-compose up -d client postgres conjur target lookup-target
}

function waitForServer() {
  echo '-----'
  echo 'Waiting for conjur server to be healthy'

  # TODO: remove this once we have HEALTHCHECK in place
  docker-compose run \
    --entrypoint bash \
    client \
    /conjurinc/ansible/wait_for_server.sh
}

function createHostFactoryToken() {
  echo '-----'
  echo "Creating Conjur host factory token"
  echo '-----'

  # get the api key from conjur for login into Conjur
  api_key=$(docker-compose exec -T conjur rails r "print Credentials['cucumber:user:admin'].api_key")

  docker-compose run \
    -e CONJUR_AUTHN_API_KEY=${api_key} \
    --entrypoint bash \
    client \
    /conjurinc/ansible/create_host_token.sh

  export HFTOKEN=$(<conjur-client-files/output/hftoken.txt)
}

function conjurizeTargetContainer() {
  echo '-----'
  echo "Conjurizing the target container with Ansible"
  echo '-----'

  ansible-playbook conjurize-container.yml
}

function RetrieveSecretInTarget() {
  echo '-----'
  echo "Retrieving secret in target container with Conjur cli"
  echo '-----'

  docker exec ansible-target bash -c /conjurinc/ansible/retreive_secrets_in_target.sh
}

function RetrieveSecretWithPlugin() {
  echo '-----'
  echo "Retrieving secret with conjur_variable lookup plugin"
  echo '-----'

#  todo - remove once the machine can be conjurized with /etc privileges
  api_key=$(docker-compose exec -T conjur rails r "print Credentials['cucumber:host:ansible-master'].api_key")
  export CONJUR_AUTHN_API_KEY=${api_key}

  ansible-playbook conjur-plugin.yml

  echo '-----'
  echo "Receiving secret inside target container from the lookup plugin variable"
  echo '-----'

  docker exec ansible-lookup-target bash -c "cat conjur_variable.txt && echo"

  echo '-----'
}

main
