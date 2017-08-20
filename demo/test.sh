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
	docker-compose up -d client postgres conjur target


	# Delay to allow time for Conjur to come up
	# TODO: remove this once we have HEALTHCHECK in place
	echo 'Waiting for conjur to be healthy'
  docker-compose run --entrypoint bash client /conjurinc/ansible/wait_for_server.sh
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
			cat >conjurinc/ansible/client-output/hftoken.txt << OUTPUT
\$HFTOKEN
OUTPUT"

		# The command above is untabbed to avoid here-document EOL
}

function runAnsible() {

	export HFTOKEN=$(<client-output/hftoken.txt)

	env | grep HFTOKEN


}

main