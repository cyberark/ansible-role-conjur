#!/bin/bash -e

echo "---- waiting for conjur v4 ----"

HEALTH_ENDPOINT="https://localhost/health"

for i in $(seq 20); do
  $(curl --silent -k ${HEALTH_ENDPOINT} | jq .ok 2>/dev/null | grep true) \
    && break
  echo .
  sleep 2
done

# So we fail if the server isn't up yet:
curl --silent -k ${HEALTH_ENDPOINT} | jq .ok 2>/dev/null | grep true
