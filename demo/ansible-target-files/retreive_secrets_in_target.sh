#!/usr/bin/env bash

echo Conjur identity is:
conjur authn whoami
echo
echo Conjur secret is:
conjur variable value target-password
echo
echo Trying to retreive ansible-master-password \(should get 403 forbidden\)
conjur variable value ansible-master-password