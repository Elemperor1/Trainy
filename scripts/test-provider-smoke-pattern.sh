#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EMPTY_ENV="$(mktemp "${TMPDIR:-/tmp}/trainy-empty-provider-env.XXXXXX")"
BAD_ENV="$(mktemp "${TMPDIR:-/tmp}/trainy-bad-provider-env.XXXXXX")"
trap 'rm -f "$EMPTY_ENV" "$BAD_ENV"' EXIT

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

rm -f /tmp/trainy-smoke-pattern.out /tmp/trainy-smoke-pattern.err
printf 'Provider smoke pattern passed: missing credentials exit 2 and strict env rejects unexpected keys.\n'
