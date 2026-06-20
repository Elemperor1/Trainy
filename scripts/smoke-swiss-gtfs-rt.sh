#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWISS_ENV_FILE="${SWISS_ENV_FILE:-$ROOT_DIR/TrainyIOS/Config/swiss.env}"
QUERY_URL="${SWISS_GTFS_RT_URL:-https://api.opentransportdata.swiss/la/gtfs-rt?format=JSON}"

# shellcheck source=scripts/lib/provider-smoke-env.sh
source "$ROOT_DIR/scripts/lib/provider-smoke-env.sh"

load_trainy_provider_env "$SWISS_ENV_FILE" SWISS_GTFS_RT_API_KEY || exit 1
require_trainy_provider_env "Swiss Open Transport Data" SWISS_GTFS_RT_API_KEY || exit $?

TMP_RESPONSE="$(mktemp "${TMPDIR:-/tmp}/trainy-swiss-smoke.XXXXXX")"
trap 'rm -f "$TMP_RESPONSE"' EXIT

trainy_smoke_http_get "$TMP_RESPONSE" \
  -H "Authorization: Bearer $SWISS_GTFS_RT_API_KEY" \
  -H "User-Agent: Trainy provider smoke" \
  "$QUERY_URL" || exit 1

RESULT_COUNT="$(jq '(.Entity // .entity // .Entities // .entities // []) | length' "$TMP_RESPONSE")"
if [[ "$RESULT_COUNT" -le 0 ]]; then
  printf 'Swiss Open Transport Data smoke failed: no GTFS-RT entities returned.\n' >&2
  exit 1
fi

print_trainy_smoke_pass "Swiss Open Transport Data" "GTFS-RT trip updates JSON test format" "$RESULT_COUNT"
