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
#  testConjurizeContainer
#  testRetrieveSecretInMaster
  testRetrieveSecretInRemote

}

function createDemoEnvironment() {
  echo "Creating demo environment"
  echo '-----'

  docker-compose pull postgres conjur client a-test
  docker-compose up -d client postgres conjur a-test
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
    --entrypoint sh \
    client \
    /conjurinc/ansible/create_host_token.sh

   export HFTOKEN=$(<conjur-client-files/output/hftoken.txt)
}

function testConjurizeContainer() {
  echo '-----'
  echo "Conjurizing the target container with Ansible"
  echo '-----'

  molecule test --scenario-name conjurize-container
}

function testRetrieveSecretInMaster() {
  echo '-----'
  echo "Retrieving secret with ansible-master identity"
  echo '-----'

  api_key=$(docker-compose exec -T conjur rails r "print Credentials['cucumber:host:ansible/ansible-master'].api_key")
  export CONJUR_AUTHN_API_KEY=${api_key}

  molecule test --scenario-name retrieve-secret-in-master

  echo '-----'
}

function testRetrieveSecretInRemote() {
  echo '-----'
  echo "Retrieving secret with conjurized target identity"
  echo '-----'

  api_key=$(docker-compose exec -T conjur rails r "print Credentials['cucumber:host:ansible/ansible-custom-target'].api_key")
  export CONJUR_CUSTOM_AUTHN_API_KEY=${api_key}

  docker exec -it a-test bash
  molecule test --scenario-name retrieve-secret-in-remote

  echo '-----'
}

main
