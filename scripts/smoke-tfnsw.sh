#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TFNSW_ENV_FILE="${TFNSW_ENV_FILE:-$ROOT_DIR/TrainyIOS/Config/tfnsw.env}"
QUERY_URL="${TFNSW_GTFS_RT_URL:-https://api.transport.nsw.gov.au/v2/gtfs/realtime/sydneytrains?debug=true}"

# shellcheck source=scripts/lib/provider-smoke-env.sh
source "$ROOT_DIR/scripts/lib/provider-smoke-env.sh"

load_trainy_provider_env "$TFNSW_ENV_FILE" TFNSW_API_KEY || exit 1
require_trainy_provider_env "Transport for NSW" TFNSW_API_KEY || exit $?

TMP_RESPONSE="$(mktemp "${TMPDIR:-/tmp}/trainy-tfnsw-smoke.XXXXXX")"
TMP_CURL_CONFIG="$(trainy_smoke_make_curl_config)"
trap 'rm -f "$TMP_RESPONSE" "$TMP_CURL_CONFIG"' EXIT

trainy_smoke_write_curl_config_option "$TMP_CURL_CONFIG" header "Authorization: apikey $TFNSW_API_KEY"

trainy_smoke_http_get "$TMP_RESPONSE" \
  --config "$TMP_CURL_CONFIG" \
  "$QUERY_URL" || exit 1

RESULT_COUNT="$(rg -c -F 'entity {' "$TMP_RESPONSE" || true)"
if [[ "$RESULT_COUNT" -le 0 ]]; then
  printf 'Transport for NSW smoke failed: no GTFS-RT entities returned.\n' >&2
  exit 1
fi

print_trainy_smoke_pass "Transport for NSW" "Sydney Trains GTFS-RT debug trip updates" "$RESULT_COUNT"
