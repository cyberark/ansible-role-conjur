#!/usr/bin/env bash

function finish {
  echo 'debug target'
  bash

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
  runAnsible
  retrieveSecretInTarget
}

function createDemoEnvironment() {
  echo "Creating demo environment"
  echo '-----'

  docker-compose build --pull target conjur-proxy-nginx
  docker-compose pull postgres conjur client
  docker-compose up -d client postgres conjur target conjur-proxy-nginx

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

function fetchCert() {
  echo "Fetch certificate using client cli"
  echo '-----'

  # get conjur client container id
  conjur_client_cid=$(docker-compose ps -q client)

  # get the pem file from conjur server
  CONJUR_ACCOUNT="cucumber"
  CONJUR_PROXY="https://conjur-proxy-nginx"
  PEM_FILE="demo.pem"

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

  docker exec ansible-target mkdir -p /usr/local/lib/summon
  docker cp summon-conjur ansible-target:/usr/local/lib/summon/summon-conjur
  docker exec -i ansible-target bash < summon.sh
}

main
