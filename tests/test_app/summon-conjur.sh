#!/usr/bin/env bash

# Summon provider that uses the Conjur CLI

varname=${1}

if [ -z ${varname} ]; then
  echo -n "No argument received!"
  exit 1
fi

conjur variable value ${varname}
