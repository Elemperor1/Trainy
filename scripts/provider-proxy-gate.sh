#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-check}"
WRANGLER_LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/trainy-proxy-wrangler-logs.XXXXXX")"
WRANGLER_REGISTRY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/trainy-proxy-wrangler-registry.XXXXXX")"
DRY_RUN_OUTPUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/trainy-proxy-dry-run.XXXXXX")"

cleanup() {
  rm -rf "$WRANGLER_LOG_DIR" "$WRANGLER_REGISTRY_DIR" "$DRY_RUN_OUTPUT_DIR"
}
trap cleanup EXIT

# Gates use a literal non-secret fixture so local or CI credentials are never
# consulted. Contract tests inject their own in-memory runtime bindings.
export NS_SUBSCRIPTION_KEY="credential-neutral-fixture"
export CLOUDFLARE_INCLUDE_PROCESS_ENV=true
export WRANGLER_LOG_PATH="$WRANGLER_LOG_DIR"
export WRANGLER_REGISTRY_PATH="$WRANGLER_REGISTRY_DIR"
export WRANGLER_SEND_METRICS=false

cd "$ROOT_DIR/provider-proxy"

case "$MODE" in
  types)
    npm exec -- wrangler types
    ;;
  test)
    npm exec -- vitest run
    ;;
  check)
    npm exec -- wrangler types
    npm exec -- tsc --noEmit
    npm exec -- tsc --noEmit -p tsconfig.test.json
    npm exec -- vitest run
    npm exec -- wrangler deploy --dry-run --outdir "$DRY_RUN_OUTPUT_DIR"
    ;;
  *)
    printf 'Usage: %s [types|test|check]\n' "${0##*/}" >&2
    exit 2
    ;;
esac
