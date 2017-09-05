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
  fetchCert
  conjurizeTargetContainer
  RetrieveSecretInTargetWithCli
  RetrieveSecretInTargetWithSummon
  RetrieveSecretInMaster
  RetrieveSecretInRemote
}

function createDemoEnvironment() {
  echo "Creating demo environment"
  echo '-----'

  docker-compose build --pull conjurized-container-test non-conjurized-container-test postgres conjur client conjur-proxy-nginx
  docker-compose up -d client postgres conjur conjur-proxy-nginx conjurized-container-test non-conjurized-container-test
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

function fetchCert() {
  echo "Fetch certificate using client cli"
  echo '-----'

  # get conjur client container id
  conjur_client_cid=$(docker-compose ps -q client)

  # get the pem file from conjur server
  CONJUR_ACCOUNT="cucumber"
  CONJUR_PROXY="https://conjur-proxy-nginx"
  PEM_FILE="conjur.pem"

  echo "remove old pem file"
  rm -rf ${PEM_FILE}

  echo "fetch pem file from proxy https server"
  exec_command='echo yes | conjur init -u '${CONJUR_PROXY}' -a '${CONJUR_ACCOUNT}' > tmp.out 2>&1'
  docker exec ${conjur_client_cid} /bin/bash -c "$exec_command"

  echo "print command output"
  print_command="cat tmp.out"
  docker exec ${conjur_client_cid} ${print_command}

  echo "copy cert outside the container"
  docker cp ${conjur_client_cid}':/root/conjur-cucumber.pem' ${PEM_FILE}

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
  export CONJUR_APPLIANCE_URL=https://localhost:8443
  export CONJUR_CERT_FILE=conjur.pem
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

  docker exec conjurized-container-test bash -c "cat conjur_env.txt && echo"

  echo '-----'
}

main
