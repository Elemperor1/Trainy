#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS_ENV_FILE="${NS_ENV_FILE:-$ROOT_DIR/TrainyIOS/Config/ns.env}"
NS_PROXY_HOST="${NS_PROXY_HOST:-127.0.0.1}"
NS_PROXY_PORT="${NS_PROXY_PORT:-8787}"
PROXY_BASE_URL="${TRAINY_PROVIDER_PROXY_BASE_URL:-http://$NS_PROXY_HOST:$NS_PROXY_PORT}"

# shellcheck source=scripts/lib/provider-smoke-env.sh
source "$ROOT_DIR/scripts/lib/provider-smoke-env.sh"

validate_trainy_loopback_host "$NS_PROXY_HOST" || exit 2
validate_trainy_port "$NS_PROXY_PORT" || exit 2
load_trainy_provider_env "$NS_ENV_FILE" NS_SUBSCRIPTION_KEY || exit 1
require_trainy_provider_env "Netherlands NS proxy" NS_SUBSCRIPTION_KEY || exit $?

PROXY_LOG="$(mktemp "${TMPDIR:-/tmp}/trainy-ns-proxy-log.XXXXXX")"
STATION_RESPONSE="$(mktemp "${TMPDIR:-/tmp}/trainy-ns-stations.XXXXXX")"
DEPARTURE_RESPONSE="$(mktemp "${TMPDIR:-/tmp}/trainy-ns-departures.XXXXXX")"
HEALTH_RESPONSE="$(mktemp "${TMPDIR:-/tmp}/trainy-ns-health.XXXXXX")"
WRANGLER_REGISTRY_PATH="$(mktemp -d "${TMPDIR:-/tmp}/trainy-ns-registry.XXXXXX")"
export WRANGLER_REGISTRY_PATH
PROXY_PID=""

cleanup() {
  if [[ -n "$PROXY_PID" ]]; then
    kill "$PROXY_PID" 2>/dev/null || true
    wait "$PROXY_PID" 2>/dev/null || true
  fi
  rm -f "$PROXY_LOG" "$STATION_RESPONSE" "$DEPARTURE_RESPONSE" "$HEALTH_RESPONSE"
  rm -rf "$WRANGLER_REGISTRY_PATH"
}
trap cleanup EXIT

if [[ -z "${TRAINY_PROVIDER_PROXY_BASE_URL:-}" ]]; then
  NS_ENV_FILE="$NS_ENV_FILE" NS_PROXY_HOST="$NS_PROXY_HOST" NS_PROXY_PORT="$NS_PROXY_PORT" \
    "$ROOT_DIR/scripts/dev-ns-proxy.sh" >"$PROXY_LOG" 2>&1 &
  PROXY_PID=$!

  ready=false
  for _ in {1..120}; do
    if curl -fsS --max-time 2 --url "$PROXY_BASE_URL/v1/health/providers" -o "$HEALTH_RESPONSE" 2>/dev/null; then
      ready=true
      break
    fi
    if ! kill -0 "$PROXY_PID" 2>/dev/null; then
      break
    fi
    sleep 0.25
  done
  if [[ "$ready" != true ]]; then
    printf 'Netherlands NS proxy smoke failed: local proxy did not become ready.\n' >&2
    if rg -q -- 'EADDRINUSE|Address already in use' "$PROXY_LOG"; then
      printf 'The validated local proxy port is already in use.\n' >&2
    else
      printf 'Wrangler startup details were suppressed to keep provider configuration out of console logs.\n' >&2
    fi
    exit 1
  fi
fi

curl -fsS --compressed --max-time 15 \
  --get --url "$PROXY_BASE_URL/v1/ns/stations" \
  --data-urlencode 'query=UT' \
  --data-urlencode 'limit=5' \
  -o "$STATION_RESPONSE"

STATION_COUNT="$(jq '.data.stations | length' "$STATION_RESPONSE")"
STATION_CODE="$(jq -r '.data.stations[0].code // empty' "$STATION_RESPONSE")"
if [[ "$STATION_COUNT" -le 0 || -z "$STATION_CODE" ]]; then
  printf 'Netherlands NS proxy smoke failed: station search returned no results.\n' >&2
  exit 1
fi
if [[ "$STATION_CODE" != "UT" ]]; then
  printf 'Netherlands NS proxy smoke failed: exact station code was not ranked first.\n' >&2
  exit 1
fi

curl -fsS --compressed --max-time 15 \
  --get --url "$PROXY_BASE_URL/v1/ns/departures" \
  --data-urlencode "station=$STATION_CODE" \
  --data-urlencode 'limit=20' \
  -o "$DEPARTURE_RESPONSE"

DEPARTURE_COUNT="$(jq '.data.departures | length' "$DEPARTURE_RESPONSE")"
if [[ "$DEPARTURE_COUNT" -le 0 ]]; then
  printf 'Netherlands NS proxy smoke failed: no departures were returned.\n' >&2
  exit 1
fi

curl -fsS --compressed --max-time 5 \
  --url "$PROXY_BASE_URL/v1/health/providers" \
  -o "$HEALTH_RESPONSE"

if ! jq -e '
  .meta.provider == "ns" and
  .meta.source == "NS Reisinformatie API" and
  .meta.attribution == "Data from Nederlandse Spoorwegen (NS)"
' "$DEPARTURE_RESPONSE" >/dev/null; then
  printf 'Netherlands NS proxy smoke failed: normalized metadata is missing.\n' >&2
  exit 1
fi

COMBINED_OUTPUT="$(<"$PROXY_LOG")$(<"$STATION_RESPONSE")$(<"$DEPARTURE_RESPONSE")$(<"$HEALTH_RESPONSE")"
if [[ "$COMBINED_OUTPUT" == *"$NS_SUBSCRIPTION_KEY"* ]]; then
  printf 'Netherlands NS proxy smoke failed: credential value appeared in output.\n' >&2
  exit 1
fi
if [[ "$COMBINED_OUTPUT" == *"ocp-apim-subscription-key"* || "$COMBINED_OUTPUT" == *"gateway.apiportal.ns.nl"* ]]; then
  printf 'Netherlands NS proxy smoke failed: upstream-only details crossed the public boundary.\n' >&2
  exit 1
fi

printf 'Provider: Netherlands NS through Trainy proxy\n'
printf 'Station result count: %s\n' "$STATION_COUNT"
printf 'Departure result count: %s\n' "$DEPARTURE_COUNT"
printf 'Freshness: %s\n' "$(jq -r '.meta.freshness' "$DEPARTURE_RESPONSE")"
printf 'Netherlands NS proxy smoke passed.\n'
