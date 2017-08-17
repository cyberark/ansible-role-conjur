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

#	docker-compose pull postgres conjur client todo: uncomment
	docker-compose build --pull ansible
	docker-compose up -d client postgres conjur ansible

	# Delay to allow time for Conjur to come up
	# TODO: remove this once we have HEALTHCHECK in place
	echo 'Waiting for conjur to be healthy'
  docker-compose run --rm --entrypoint bash ansible ./demo/wait_for_server.sh
}

function createHostFactoryToken() {
  echo "Creating Conjur host factory token"
  echo '-----'

	client_cid=$(docker-compose ps -q client)

	# copy test-policy into a /tmp/test-policy within the client container
  docker cp test-policy ${client_cid}:/test-policy

  # get the api key from conjur for login into Conjur
	api_key=$(docker-compose exec -T conjur rails r "print Credentials['cucumber:user:admin'].api_key")

	docker exec -e CONJUR_AUTHN_API_KEY=${api_key} \
		${client_cid} \
    /bin/bash -c "conjur policy load root /test-policy/root.yml && \
    	conjur variable values add password mysecretpassword && \
			export HFTOKEN=\$(conjur hostfactory tokens create --duration-days=365 ansible-factory | jq '.[0].token') && \
			cat >conjurinc/ansible/output/output.sh << OUTPUT
#!/usr/bin/env bash
# Run the following in ansible-conjur-role...
export HFTOKEN=\$HFTOKEN
#vagrant up
# Now add the vagrant user to the conjur group and SSH into the vagrant machine.
#vagrant ssh -c \"sudo usermod -a -G conjur vagrant\" && vagrant ssh
#conjur variable value password
OUTPUT"

		# The command above is untabbed to avoid here-document EOL
}

function runAnsible() {

	ansible_cid=$(docker-compose ps -q ansible)

	docker cp output ${ansible_cid}:/tmp
	docker exec -it ${ansible_cid} /bin/bash
}

main