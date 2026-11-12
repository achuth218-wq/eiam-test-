#!/usr/bin/env bash
# Calls one endpoint per API through the Kong data plane and prints the HTTP status.
# Usage: ./scripts/smoke-test.sh https://<your-data-plane-host>
set -u
PROXY="${1:?usage: $0 <proxy-url>}"
PROXY="${PROXY%/}"

declare -a CHECKS=(
  "/jsonplaceholder/todos/1"
  "/catfact/fact"
  "/chucknorris/jokes/random"
  "/dog/breeds/image/random"
  "/agify/?name=michael"
  "/genderize/?name=peter"
  "/nationalize/?name=nathaniel"
  "/open-meteo/forecast?latitude=17.38&longitude=78.48&current_weather=true"
  "/restcountries/name/india"
  "/pokeapi/pokemon/ditto"
  "/jokes/random_joke"
  "/zippopotam/us/90210"
)

fail=0
for p in "${CHECKS[@]}"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$PROXY$p")
  if [[ "$code" =~ ^2 ]]; then echo "OK   $code  $p"; else echo "FAIL $code  $p"; fail=1; fi
done
exit $fail
