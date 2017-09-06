#!/bin/bash -e

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
  fetchCert
  testConjurizeContainer
  testRetrieveSecretInMaster
  testRetrieveSecretInRemote
}

function createDemoEnvironment() {
  echo "Creating demo environment"
  echo '-----'

  docker-compose pull postgres conjur client conjur-proxy-nginx
  docker-compose up --build -d client postgres conjur conjur-proxy-nginx
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

   export HFTOKEN=$(<test-files/output/hftoken.txt)
}

function fetchCert() {
  echo "Fetch certificate using client cli"
  echo '-----'

  docker-compose run \
    -e CONJUR_AUTHN_API_KEY=${api_key} \
    --entrypoint sh \
    client \
    /conjurinc/ansible/fetch_cert.sh

  rm -f molecule/conjur.pem
  cp test-files/output/conjur.pem molecule
}

function testConjurizeContainer() {
  echo '-----'
  echo "Conjurizing the target container with Ansible"
  echo '-----'

  env MOLECULE_DEBUG=1 \
    molecule test -s configure-conjur-identity
}

function testRetrieveSecretInMaster() {
  echo '-----'
  echo "Retrieving secret with ansible-master identity"
  echo '-----'

  api_key=$(docker-compose exec -T conjur rails r "print Credentials['cucumber:host:ansible/ansible-master'].api_key")
  export CONJUR_AUTHN_API_KEY=${api_key}

  molecule test -s retrieve-secret-in-master

  echo '-----'
}

function testRetrieveSecretInRemote() {
  echo '-----'
  echo "Retrieving secret with conjurized target identity"
  echo '-----'

  api_key=$(docker-compose exec -T conjur rails r "print Credentials['cucumber:host:ansible/ansible-custom-target'].api_key")
  export CONJUR_CUSTOM_AUTHN_API_KEY=${api_key}

  molecule test -s retrieve-secret-in-remote

  echo '-----'
}

main
