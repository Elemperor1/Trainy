#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS_ENV_FILE="${NS_ENV_FILE:-$ROOT_DIR/TrainyIOS/Config/ns.env}"
QUERY_STATION="${NS_STATION:-UT}"
QUERY_URL="https://gateway.apiportal.ns.nl/reisinformatie-api/api/v2/departures?station=$QUERY_STATION"

# shellcheck source=scripts/lib/provider-smoke-env.sh
source "$ROOT_DIR/scripts/lib/provider-smoke-env.sh"

load_trainy_provider_env "$NS_ENV_FILE" NS_SUBSCRIPTION_KEY || exit 1
require_trainy_provider_env "Netherlands NS" NS_SUBSCRIPTION_KEY || exit $?

TMP_RESPONSE="$(mktemp "${TMPDIR:-/tmp}/trainy-ns-smoke.XXXXXX")"
TMP_CURL_CONFIG="$(trainy_smoke_make_curl_config)"
trap 'rm -f "$TMP_RESPONSE" "$TMP_CURL_CONFIG"' EXIT

trainy_smoke_write_curl_config_option "$TMP_CURL_CONFIG" header "Ocp-Apim-Subscription-Key: $NS_SUBSCRIPTION_KEY"
trainy_smoke_write_curl_config_option "$TMP_CURL_CONFIG" header "Accept: application/json"

trainy_smoke_http_get "$TMP_RESPONSE" \
  --config "$TMP_CURL_CONFIG" \
  "$QUERY_URL" || exit 1

RESULT_COUNT="$(jq '.payload.departures | length' "$TMP_RESPONSE")"
if [[ "$RESULT_COUNT" -le 0 ]]; then
  printf 'Netherlands NS smoke failed: no departures returned for station %s.\n' "$QUERY_STATION" >&2
  exit 1
fi

print_trainy_smoke_pass "Netherlands NS" "departures station=$QUERY_STATION" "$RESULT_COUNT"
