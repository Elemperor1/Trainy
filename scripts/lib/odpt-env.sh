#!/usr/bin/env bash

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

trainy_warn_env_permissions() {
  local env_file="$1"
  local mode
  mode="$(stat -f '%Lp' "$env_file" 2>/dev/null || stat -c '%a' "$env_file" 2>/dev/null || true)"
  [[ "$mode" =~ ^[0-7]+$ ]] || return 0

  local permissions=$((8#$mode))
  if (( permissions & 077 )); then
    printf 'Warning: %s is readable by group or others; consider chmod 600.\n' "$env_file" >&2
  fi
}

load_trainy_odpt_env() {
  local env_file="$1"
  [[ -n "$env_file" && -f "$env_file" ]] || return 0

  trainy_warn_env_permissions "$env_file"

  local line trimmed key value parsed_value='' saw_key=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    trimmed="$(trainy_trim "$line")"
    [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue

    if [[ "$trimmed" != *=* ]]; then
      printf 'Unsupported entry in %s. Only ODPT_CONSUMER_KEY=... is allowed.\n' "$env_file" >&2
      return 1
    fi

    key="${trimmed%%=*}"
    key="$(trainy_trim "$key")"
    if [[ "$key" != ODPT_CONSUMER_KEY ]]; then
      printf 'Unsupported entry in %s. Only ODPT_CONSUMER_KEY=... is allowed.\n' "$env_file" >&2
      return 1
    fi
    if (( saw_key != 0 )); then
      printf 'Duplicate ODPT_CONSUMER_KEY entry found in %s. Keep exactly one assignment.\n' "$env_file" >&2
      return 1
    fi
    value="${trimmed#*=}"
    value="$(trainy_trim "$value")"

    if [[ "$value" == \"* && "$value" != *\" ]] || [[ "$value" == \'* && "$value" != *\' ]]; then
      printf 'Malformed quoted value found in %s for %s.\n' "$env_file" "$key" >&2
      return 1
    elif [[ "$value" != \"*\" && "$value" != \'*\' ]]; then
      value="${value%%#*}"
      value="$(trainy_trim "$value")"
    fi

    value="$(trainy_unquote_env_value "$value")"
    if [[ "$value" == *'$('* || "$value" == *'`'* ]]; then
      printf 'Unsafe command substitution syntax found in %s for %s.\n' "$env_file" "$key" >&2
      return 1
    fi

    parsed_value="$value"
    saw_key=1
  done < "$env_file"

  if (( saw_key == 0 )); then
    printf 'No ODPT_CONSUMER_KEY entry found in %s.\n' "$env_file" >&2
  else
    export ODPT_CONSUMER_KEY="$parsed_value"
  fi
}
