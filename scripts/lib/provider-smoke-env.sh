#!/usr/bin/env bash

trainy_smoke_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

trainy_smoke_unquote_env_value() {
  local value="$1"
  if [[ "$value" == \"*\" && "$value" == *\" && ${#value} -ge 2 ]]; then
    value="${value:1:${#value}-2}"
  elif [[ "$value" == \'*\' && "$value" == *\' && ${#value} -ge 2 ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "$value"
}

trainy_smoke_warn_env_permissions() {
  local env_file="$1"
  local mode
  mode="$(stat -f '%Lp' "$env_file" 2>/dev/null || stat -c '%a' "$env_file" 2>/dev/null || true)"
  [[ "$mode" =~ ^[0-7]+$ ]] || return 0

  local permissions=$((8#$mode))
  if (( permissions & 077 )); then
    printf 'Warning: %s is readable by group or others; consider chmod 600.\n' "$env_file" >&2
  fi
}

trainy_smoke_key_allowed() {
  local key="$1"
  shift
  local allowed_key
  for allowed_key in "$@"; do
    [[ "$key" == "$allowed_key" ]] && return 0
  done
  return 1
}

load_trainy_provider_env() {
  local env_file="$1"
  shift
  local allowed_keys=("$@")
  [[ ${#allowed_keys[@]} -gt 0 ]] || return 0
  [[ -n "$env_file" && -f "$env_file" ]] || return 0

  trainy_smoke_warn_env_permissions "$env_file"

  local line trimmed key value seen_keys='|'
  local -a parsed_keys=()
  local -a parsed_values=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    trimmed="$(trainy_smoke_trim "$line")"
    [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue

    if [[ "$trimmed" != *=* ]]; then
      printf 'Unsupported entry in %s. Expected KEY=value lines only.\n' "$env_file" >&2
      return 1
    fi

    key="${trimmed%%=*}"
    key="$(trainy_smoke_trim "$key")"
    if ! trainy_smoke_key_allowed "$key" "${allowed_keys[@]}"; then
      printf 'Unsupported key %s in %s. Expected only: %s.\n' "$key" "$env_file" "${allowed_keys[*]}" >&2
      return 1
    fi
    if [[ "$seen_keys" == *"|$key|"* ]]; then
      printf 'Duplicate %s entry found in %s. Keep exactly one assignment.\n' "$key" "$env_file" >&2
      return 1
    fi

    value="${trimmed#*=}"
    value="$(trainy_smoke_trim "$value")"

    if [[ "$value" == \"* && "$value" != *\" ]] || [[ "$value" == \'* && "$value" != *\' ]]; then
      printf 'Malformed quoted value found in %s for %s.\n' "$env_file" "$key" >&2
      return 1
    elif [[ "$value" != \"*\" && "$value" != \'*\' ]]; then
      value="${value%%#*}"
      value="$(trainy_smoke_trim "$value")"
    fi

    value="$(trainy_smoke_unquote_env_value "$value")"
    if [[ "$value" == *'$('* || "$value" == *'`'* ]]; then
      printf 'Unsafe command substitution syntax found in %s for %s.\n' "$env_file" "$key" >&2
      return 1
    fi

    parsed_keys+=("$key")
    parsed_values+=("$value")
    seen_keys+="$key|"
  done < "$env_file"

  local index
  for (( index = 0; index < ${#parsed_keys[@]}; index += 1 )); do
    export "${parsed_keys[$index]}=${parsed_values[$index]}"
  done
}

validate_trainy_loopback_host() {
  local host="$1"
  case "$host" in
    127.0.0.1|localhost) return 0 ;;
    *)
      printf 'Local proxy host must be 127.0.0.1 or localhost.\n' >&2
      return 1
      ;;
  esac
}

validate_trainy_port() {
  local port="$1"
  if [[ ! "$port" =~ ^[0-9]{1,5}$ ]]; then
    printf 'Local proxy port must be an integer from 1 through 65535.\n' >&2
    return 1
  fi
  local numeric_port=$((10#$port))
  if (( numeric_port < 1 || numeric_port > 65535 )); then
    printf 'Local proxy port must be an integer from 1 through 65535.\n' >&2
    return 1
  fi
}

require_trainy_provider_env() {
  local provider="$1"
  shift
  local missing=()
  local key
  for key in "$@"; do
    if [[ -z "${!key:-}" ]]; then
      missing+=("$key")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    printf '%s smoke missing credential(s): %s.\n' "$provider" "${missing[*]}" >&2
    return 2
  fi
}

trainy_smoke_http_get() {
  local output_file="$1"
  shift
  local http_code
  http_code="$(curl -sS -L --compressed --max-time 30 -o "$output_file" -w '%{http_code}' "$@" || true)"
  if [[ "$http_code" != 2* ]]; then
    printf 'Provider/network request failed with HTTP %s.\n' "$http_code" >&2
    return 1
  fi
}

trainy_smoke_curl_config_quote() {
  local value="$1"
  if [[ "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
    printf 'Unsafe newline found in curl config value.\n' >&2
    return 1
  fi
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

trainy_smoke_write_curl_config_option() {
  local config_file="$1"
  local option="$2"
  local value="$3"
  printf '%s = ' "$option" >> "$config_file"
  trainy_smoke_curl_config_quote "$value" >> "$config_file"
  printf '\n' >> "$config_file"
}

trainy_smoke_make_curl_config() {
  local config_file
  config_file="$(mktemp "${TMPDIR:-/tmp}/trainy-curl-config.XXXXXX")"
  chmod 600 "$config_file"
  printf '%s' "$config_file"
}

print_trainy_smoke_pass() {
  local provider="$1"
  local query="$2"
  local result_count="$3"
  printf 'Provider: %s\n' "$provider"
  printf 'Query: %s\n' "$query"
  printf 'Result count: %s\n' "$result_count"
  printf '%s smoke passed.\n' "$provider"
}
