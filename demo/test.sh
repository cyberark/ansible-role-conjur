#!/usr/bin/env bash

function finish {
  echo 'Removing test environment'
  echo '-----'
  docker-compose down -v
}
trap finish EXIT

function main() {
  createTestEnvironment
	createHostFactoryToken
	runAnsible
}

function createTestEnvironment() {
  echo "Creating test environment"
  echo '-----'

	docker-compose pull postgres conjur client target
	docker-compose build --pull ansible
	docker-compose up -d client postgres conjur ansible target

	# Delay to allow time for Conjur to come up
	# TODO: remove this once we have HEALTHCHECK in place
	echo 'Waiting for conjur to be healthy'
  docker-compose run --rm --entrypoint bash ansible ./demo/wait_for_server.sh
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
			export HFTOKEN=\$(conjur hostfactory tokens create --duration-days=365 ansible-factory | jq '.[0].token') && \
			cat >conjurinc/ansible/output/hftoken.txt << OUTPUT
\$HFTOKEN
OUTPUT"

		# The command above is untabbed to avoid here-document EOL
}

function runAnsible() {

	docker exec -e HFTOKEN=$(<client-output/hftoken.txt) \
		-it ansible-runner /bin/bash -c "env | grep HFTOKEN"
}

main