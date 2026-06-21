#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EMPTY_ENV="$(mktemp "${TMPDIR:-/tmp}/trainy-empty-provider-env.XXXXXX")"
BAD_ENV="$(mktemp "${TMPDIR:-/tmp}/trainy-bad-provider-env.XXXXXX")"
CURL_CONFIG=""
trap 'rm -f "$EMPTY_ENV" "$BAD_ENV" "$CURL_CONFIG"' EXIT

# shellcheck source=scripts/lib/provider-smoke-env.sh
source "$ROOT_DIR/scripts/lib/provider-smoke-env.sh"

printf 'UNEXPECTED_KEY=value\n' > "$BAD_ENV"

assert_exit_code() {
  local expected="$1"
  local label="$2"
  shift 2

  set +e
  "$@" >/tmp/trainy-smoke-pattern.out 2>/tmp/trainy-smoke-pattern.err
  local actual=$?
  set -e

  if [[ "$actual" -ne "$expected" ]]; then
    printf '%s expected exit %s, got %s.\n' "$label" "$expected" "$actual" >&2
    printf 'stderr:\n' >&2
    sed -n '1,20p' /tmp/trainy-smoke-pattern.err >&2
    return 1
  fi
}

assert_exit_code 2 "NS missing credential" env NS_SUBSCRIPTION_KEY= NS_ENV_FILE="$EMPTY_ENV" "$ROOT_DIR/scripts/smoke-ns.sh"
assert_exit_code 2 "TDX missing credential" env TDX_CLIENT_ID= TDX_CLIENT_SECRET= TDX_ENV_FILE="$EMPTY_ENV" "$ROOT_DIR/scripts/smoke-tdx.sh"
assert_exit_code 2 "TfNSW missing credential" env TFNSW_API_KEY= TFNSW_ENV_FILE="$EMPTY_ENV" "$ROOT_DIR/scripts/smoke-tfnsw.sh"
assert_exit_code 2 "Swiss missing credential" env SWISS_GTFS_RT_API_KEY= SWISS_ENV_FILE="$EMPTY_ENV" "$ROOT_DIR/scripts/smoke-swiss-gtfs-rt.sh"
assert_exit_code 2 "France missing credential" env TRANSPORT_DATA_GOUV_FR_TOKEN= SNCF_API_TOKEN= FRANCE_ENV_FILE="$EMPTY_ENV" "$ROOT_DIR/scripts/smoke-france-sncf.sh"

assert_exit_code 1 "Strict env rejects unknown key" env NS_SUBSCRIPTION_KEY= NS_ENV_FILE="$BAD_ENV" "$ROOT_DIR/scripts/smoke-ns.sh"

CURL_CONFIG="$(trainy_smoke_make_curl_config)"
CONFIG_MODE="$(stat -f '%Lp' "$CURL_CONFIG" 2>/dev/null || stat -c '%a' "$CURL_CONFIG" 2>/dev/null || true)"
if [[ "$CONFIG_MODE" != "600" ]]; then
  printf 'Curl config expected mode 600, got %s.\n' "${CONFIG_MODE:-unknown}" >&2
  exit 1
fi

if rg -n -- '-H ".*\$(NS_SUBSCRIPTION_KEY|TFNSW_API_KEY|SWISS_GTFS_RT_API_KEY|ACCESS_TOKEN|API_KEY)"|--data-urlencode "client_(id|secret)=\$' \
  "$ROOT_DIR/scripts/smoke-ns.sh" \
  "$ROOT_DIR/scripts/smoke-tdx.sh" \
  "$ROOT_DIR/scripts/smoke-tfnsw.sh" \
  "$ROOT_DIR/scripts/smoke-swiss-gtfs-rt.sh" \
  "$ROOT_DIR/scripts/capture-swiss-gtfs-rt-fixture.sh" >/tmp/trainy-smoke-pattern.out
then
  printf 'Provider smoke scripts must not pass credentials directly in external curl arguments.\n' >&2
  sed -n '1,20p' /tmp/trainy-smoke-pattern.out >&2
  exit 1
fi

rm -f /tmp/trainy-smoke-pattern.out /tmp/trainy-smoke-pattern.err
printf 'Provider smoke pattern passed: missing credentials exit 2, strict env rejects unexpected keys, and curl credentials stay out of external argv.\n'
