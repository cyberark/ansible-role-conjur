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
	RetrieveSecretInTarget
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
	echo 'Waiting for conjur to be healthy'
	echo '-----'

	# TODO: remove this once we have HEALTHCHECK in place
  docker-compose run --entrypoint bash client /conjurinc/ansible/wait_for_server.sh

	echo '-----'
}
function createHostFactoryToken() {
  echo "Creating Conjur host factory token"
  echo '-----'

  # get the api key from conjur for login into Conjur
	api_key=$(docker-compose exec -T conjur rails r "print Credentials['cucumber:user:admin'].api_key")

	docker exec -e CONJUR_AUTHN_API_KEY=${api_key} \
		ansible-conjur-client \
    /bin/bash -c "conjur policy load root /conjurinc/ansible/policies/root.yml && \
    	conjur variable values add password mysecretpassword && \
			export HFTOKEN=\$(conjur hostfactory tokens create --duration-days=365 ansible-factory | jq -r '.[0].token') && \
			cat >conjurinc/ansible/client-output/hftoken.txt << OUTPUT
\$HFTOKEN
OUTPUT"

		# The command above is untabbed to avoid here-document EOL

	echo '-----'
}

function runAnsible() {
  echo "Running Ansible playbook"
  echo '-----'

	export HFTOKEN=$(<client-output/hftoken.txt)

	ansible-playbook demo.yml

  echo '-----'
}

function RetrieveSecretInTarget() {
	echo "Fetching secret in target container"
  echo '-----'

	docker exec ansible-target bash -c "echo Conjur identity is: && conjur authn whoami && echo && echo Conjur secret is: \
		&& conjur variable value password && echo"

	echo '-----'
}

main