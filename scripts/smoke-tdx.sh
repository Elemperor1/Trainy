#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TDX_ENV_FILE="${TDX_ENV_FILE:-$ROOT_DIR/TrainyIOS/Config/tdx.env}"
TOKEN_URL="https://tdx.transportdata.tw/auth/realms/TDXConnect/protocol/openid-connect/token"
THSR_URL='https://tdx.transportdata.tw/api/basic/v2/Rail/THSR/GeneralTimetable?$top=1&$format=JSON'
TRA_URL='https://tdx.transportdata.tw/api/basic/v2/Rail/TRA/LiveBoard/Station/1000?$top=3&$format=JSON'

# shellcheck source=scripts/lib/provider-smoke-env.sh
source "$ROOT_DIR/scripts/lib/provider-smoke-env.sh"

load_trainy_provider_env "$TDX_ENV_FILE" TDX_CLIENT_ID TDX_CLIENT_SECRET || exit 1
require_trainy_provider_env "Taiwan TDX" TDX_CLIENT_ID TDX_CLIENT_SECRET || exit $?

TMP_TOKEN="$(mktemp "${TMPDIR:-/tmp}/trainy-tdx-token.XXXXXX")"
TMP_THSR="$(mktemp "${TMPDIR:-/tmp}/trainy-tdx-thsr.XXXXXX")"
TMP_TRA="$(mktemp "${TMPDIR:-/tmp}/trainy-tdx-tra.XXXXXX")"
trap 'rm -f "$TMP_TOKEN" "$TMP_THSR" "$TMP_TRA"' EXIT

HTTP_CODE="$(
  curl -sS -L --compressed --max-time 30 \
    -X POST \
    -o "$TMP_TOKEN" \
    -w '%{http_code}' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode 'grant_type=client_credentials' \
    --data-urlencode "client_id=$TDX_CLIENT_ID" \
    --data-urlencode "client_secret=$TDX_CLIENT_SECRET" \
    "$TOKEN_URL" || true
)"
if [[ "$HTTP_CODE" != 2* ]]; then
  printf 'Taiwan TDX smoke failed during token request with HTTP %s.\n' "$HTTP_CODE" >&2
  exit 1
fi

ACCESS_TOKEN="$(jq -r '.access_token // empty' "$TMP_TOKEN")"
if [[ -z "$ACCESS_TOKEN" ]]; then
  printf 'Taiwan TDX smoke failed: token response did not include an access token.\n' >&2
  exit 1
fi

trainy_smoke_http_get "$TMP_THSR" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Accept: application/json" \
  "$THSR_URL" || exit 1
trainy_smoke_http_get "$TMP_TRA" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Accept: application/json" \
  "$TRA_URL" || exit 1

THSR_COUNT="$(jq 'length' "$TMP_THSR")"
TRA_COUNT="$(jq 'length' "$TMP_TRA")"
RESULT_COUNT="$((THSR_COUNT + TRA_COUNT))"
if [[ "$RESULT_COUNT" -le 0 ]]; then
  printf 'Taiwan TDX smoke failed: THSR and TRA queries returned no records.\n' >&2
  exit 1
fi

print_trainy_smoke_pass "Taiwan TDX" "THSR timetable top=1; TRA Taipei live-board top=3" "$RESULT_COUNT"
