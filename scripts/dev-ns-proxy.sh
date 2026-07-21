#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS_ENV_FILE="${NS_ENV_FILE:-$ROOT_DIR/TrainyIOS/Config/ns.env}"
NS_PROXY_HOST="${NS_PROXY_HOST:-127.0.0.1}"
NS_PROXY_PORT="${NS_PROXY_PORT:-8787}"

# shellcheck source=scripts/lib/provider-smoke-env.sh
source "$ROOT_DIR/scripts/lib/provider-smoke-env.sh"

validate_trainy_loopback_host "$NS_PROXY_HOST" || exit 2
validate_trainy_port "$NS_PROXY_PORT" || exit 2
load_trainy_provider_env "$NS_ENV_FILE" NS_SUBSCRIPTION_KEY || exit 1
require_trainy_provider_env "Netherlands NS proxy" NS_SUBSCRIPTION_KEY || exit $?

# Wrangler 4.112 reads only the secret names declared in `secrets.required`
# from process.env. This keeps the credential in memory and avoids a .dev.vars
# file or a command-line `--var` value.
export CLOUDFLARE_INCLUDE_PROCESS_ENV=true
WRANGLER_RUNTIME_DIR="$(mktemp -d "${TMPDIR:-/tmp}/trainy-ns-proxy-runtime.XXXXXX")"
cleanup() {
  rm -rf "$WRANGLER_RUNTIME_DIR"
}
trap cleanup EXIT

export WRANGLER_LOG_PATH="${WRANGLER_LOG_PATH:-$WRANGLER_RUNTIME_DIR/wrangler.log}"
export WRANGLER_REGISTRY_PATH="${WRANGLER_REGISTRY_PATH:-$WRANGLER_RUNTIME_DIR/registry}"
export WRANGLER_SEND_METRICS=false

cd "$ROOT_DIR/provider-proxy"
npm exec -- wrangler dev --local --ip "$NS_PROXY_HOST" --port "$NS_PROXY_PORT"
