#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRANCE_ENV_FILE="${FRANCE_ENV_FILE:-$ROOT_DIR/TrainyIOS/Config/france-sncf.env}"
QUERY_URL="${FRANCE_SNCF_DATASET_URL:-https://transport.data.gouv.fr/api/datasets}"

# shellcheck source=scripts/lib/provider-smoke-env.sh
source "$ROOT_DIR/scripts/lib/provider-smoke-env.sh"

load_trainy_provider_env "$FRANCE_ENV_FILE" TRANSPORT_DATA_GOUV_FR_TOKEN SNCF_API_TOKEN || exit 1
require_trainy_provider_env "France SNCF" TRANSPORT_DATA_GOUV_FR_TOKEN || exit $?

TMP_RESPONSE="$(mktemp "${TMPDIR:-/tmp}/trainy-france-sncf-smoke.XXXXXX")"
trap 'rm -f "$TMP_RESPONSE"' EXIT

trainy_smoke_http_get "$TMP_RESPONSE" "$QUERY_URL" || exit 1

RESULT_COUNT="$(jq '[.[] | select(.id == "6853c089b3ed5781f6adfdf7" or ((.title // "") | test("SNCF"; "i")))] | length' "$TMP_RESPONSE")"
if [[ "$RESULT_COUNT" -le 0 ]]; then
  printf 'France SNCF smoke failed: no SNCF rail dataset metadata found.\n' >&2
  exit 1
fi

print_trainy_smoke_pass "France SNCF" "transport.data.gouv.fr SNCF dataset metadata" "$RESULT_COUNT"
