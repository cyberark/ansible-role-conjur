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
  RetrieveSecretInTargetWithCli
  RetrieveSecretInTargetWithSummon
  RetrieveSecretInMaster
  RetrieveSecretInRemote
}

function createDemoEnvironment() {
  echo "Creating demo environment"
  echo '-----'

  docker-compose build --pull conjurized-container-test non-conjurized-container-test
  docker-compose pull postgres conjur client
  docker-compose up -d client postgres conjur conjurized-container-test non-conjurized-container-test
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
}

function conjurizeTargetContainer() {
  echo '-----'
  echo "Conjurizing the target container with Ansible"
  echo '-----'

  export HFTOKEN=$(<conjur-client-files/output/hftoken.txt)

  ansible-playbook playbooks/conjurize-container.yml
}

function RetrieveSecretInTargetWithCli() {
  echo '-----'
  echo "Retrieving secret in target container with Conjur cli"
  echo '-----'

  docker exec conjurized-container-test bash -c /conjurinc/ansible/conjur_cli.sh
}

function RetrieveSecretInTargetWithSummon() {
  docker exec conjurized-container-test bash -c /conjurinc/ansible/summon.sh
}

function RetrieveSecretInMaster() {
  echo '-----'
  echo "Retrieving secret with ansible-master identity"
  echo '-----'

  # Adding ansible-master identity & conf instead of conjurizing host machine
  export CONJUR_ACCOUNT=cucumber
  export CONJUR_APPLIANCE_URL=http://127.0.0.1:3000
  export CONJUR_CERT_FILE=demo.pem
  export CONJUR_AUTHN_LOGIN=host/ansible/ansible-master

  api_key=$(docker-compose exec -T conjur rails r "print Credentials['cucumber:host:ansible/ansible-master'].api_key")
  export CONJUR_AUTHN_API_KEY=${api_key}

  ansible-playbook playbooks/retrieve_secret_in_master.yml

  docker exec non-conjurized-container-test bash -c "cat conjur_secrets.txt && echo"

  echo '-----'
}

function RetrieveSecretInRemote() {
  echo '-----'
  echo "Retrieving secret with conjurized target identity"
  echo '-----'

  ansible-playbook playbooks/retrieve_secret_in_remote.yml

  docker exec conjurized-container-test bash -c "cat conjur_secrets.txt && echo"

  echo '-----'
}

main
