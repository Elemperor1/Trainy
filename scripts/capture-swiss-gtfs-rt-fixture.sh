#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWISS_ENV_FILE="${SWISS_ENV_FILE:-$ROOT_DIR/.env}"
OUTPUT_FILE="${OUTPUT_FILE:-$ROOT_DIR/Tests/TrainyCoreTests/Fixtures/future_providers/swiss_gtfs_rt_trip_updates.json}"
EVIDENCE_FILE="${EVIDENCE_FILE:-$ROOT_DIR/Tests/TrainyCoreTests/Fixtures/future_providers/swiss_gtfsrt_access_disallowed.json}"
ENDPOINT="${SWISS_GTFS_RT_URL:-https://api.opentransportdata.swiss/la/gtfs-rt?format=JSON}"
USER_AGENT="${SWISS_USER_AGENT:-Trainy fixture capture}"

# shellcheck source=scripts/lib/provider-smoke-env.sh
source "$ROOT_DIR/scripts/lib/provider-smoke-env.sh"

trainy_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

trainy_unquote_env_value() {
  local value="$1"
  if [[ "$value" == \"*\" && "$value" == *\" && ${#value} -ge 2 ]]; then
    value="${value:1:${#value}-2}"
  elif [[ "$value" == \'*\' && "$value" == *\' && ${#value} -ge 2 ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "$value"
}

load_swiss_env() {
  local env_file="$1"
  [[ -n "$env_file" && -f "$env_file" ]] || return 0

  local line trimmed key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    trimmed="$(trainy_trim "$line")"
    [[ -z "$trimmed" || "$trimmed" == \#* || "$trimmed" != *=* ]] && continue

    key="${trimmed%%=*}"
    value="${trimmed#*=}"
    value="$(trainy_trim "$value")"

    if [[ "$value" != \"*\" && "$value" != \'*\' ]]; then
      value="${value%%#*}"
      value="$(trainy_trim "$value")"
    fi

    value="$(trainy_unquote_env_value "$value")"
    if [[ "$value" == *'$('* || "$value" == *'`'* ]]; then
      printf 'Unsafe command substitution syntax found in %s for %s.\n' "$env_file" "$key" >&2
      return 1
    fi

    case "$key" in
      SWISS_GTFS_RT_API_KEY|SWISS_OPEN_TRANSPORT_GTFS_RT_API_KEY|SWISS_OPEN_TRANSPORT_API_KEY)
        export "$key=$value"
        ;;
    esac
  done < "$env_file"
}

load_swiss_env "$SWISS_ENV_FILE"

API_KEY="${SWISS_GTFS_RT_API_KEY:-${SWISS_OPEN_TRANSPORT_GTFS_RT_API_KEY:-${SWISS_OPEN_TRANSPORT_API_KEY:-}}}"
if [[ -z "$API_KEY" ]]; then
  printf 'No Swiss GTFS-RT API key configured. Add the tedp_gtfs_rt credential token as SWISS_GTFS_RT_API_KEY in %s.\n' "$SWISS_ENV_FILE" >&2
  exit 2
fi

TMP_RESPONSE="$(mktemp "${TMPDIR:-/tmp}/trainy-swiss-gtfsrt.XXXXXX")"
TMP_CURL_CONFIG="$(trainy_smoke_make_curl_config)"
trap 'rm -f "$TMP_RESPONSE" "$TMP_CURL_CONFIG"' EXIT

trainy_smoke_write_curl_config_option "$TMP_CURL_CONFIG" header "Authorization: Bearer $API_KEY"
trainy_smoke_write_curl_config_option "$TMP_CURL_CONFIG" header "User-Agent: $USER_AGENT"

HTTP_CODE="$(
  curl -sS -L --compressed --max-time 30 \
    -o "$TMP_RESPONSE" \
    -w '%{http_code}' \
    --config "$TMP_CURL_CONFIG" \
    "$ENDPOINT" || true
)"

if [[ "$HTTP_CODE" != 2* ]]; then
  mkdir -p "$(dirname "$EVIDENCE_FILE")"
  jq \
    --arg captured_at "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    --arg source_url "$ENDPOINT" \
    --arg status "$HTTP_CODE" \
    '{
      fixture: {
        provider: "Switzerland Open Transport Data",
        captured_at: $captured_at,
        source_url: $source_url,
        required_api_product: "tedp_gtfs_rt",
        result: "access disallowed or unavailable for configured key",
        http_status: $status
      },
      response: .
    }' "$TMP_RESPONSE" > "$EVIDENCE_FILE"

  printf 'Swiss GTFS-RT request returned HTTP %s. Evidence written to %s.\n' "$HTTP_CODE" "$EVIDENCE_FILE" >&2
  printf 'If this used SWISS_OPEN_TRANSPORT_API_KEY, configure the tedp_gtfs_rt token as SWISS_GTFS_RT_API_KEY and rerun.\n' >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"
jq \
  --arg captured_at "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  --arg source_url "$ENDPOINT" \
  'def feed_header: (.Header // .header // .FeedHeader // .feedHeader // {});
   def feed_entities: (.Entity // .entity // .Entities // .entities // []);
   {
     fixture: {
       provider: "Switzerland Open Transport Data",
       captured_at: $captured_at,
       source_url: $source_url,
       api_product: "tedp_gtfs_rt",
       format: "GTFS-RT JSON test format"
     },
     header: feed_header,
     entities: (feed_entities[0:1])
   }' "$TMP_RESPONSE" > "$OUTPUT_FILE"

printf 'Swiss GTFS-RT fixture written to %s.\n' "$OUTPUT_FILE"
