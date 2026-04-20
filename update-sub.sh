#!/usr/bin/env bash
set -euo pipefail

RUNTIME="/etc/xray/runtime"
BASE="/etc/xray/base.template.json"
SUB_JSON="${RUNTIME}/sub.json"
CFG_NEW="${RUNTIME}/config.new.json"
CFG="${RUNTIME}/config.json"
RESTART_FLAG="${RUNTIME}/restart.required"

SUB_URL="${SUB_URL:-}"
if [[ -z "$SUB_URL" ]]; then
  echo "[update-sub] SUB_URL is empty"
  exit 2
fi

mkdir -p "$RUNTIME"

echo "[update-sub] fetching subscription..."
curl -4fsSL "$SUB_URL" -o "$SUB_JSON"

# sanity: subscription must be json
if ! jq -e . "$SUB_JSON" >/dev/null 2>&1; then
  echo "[update-sub] subscription is not valid JSON. First 200 bytes:"
  head -c 200 "$SUB_JSON" || true
  exit 3
fi

echo "[update-sub] building config..."
python3 /usr/local/bin/build_config.py "$BASE" "$SUB_JSON" "$CFG_NEW"

# sanity: file exists + not empty
if [[ ! -s "$CFG_NEW" ]]; then
  echo "[update-sub] build_config produced empty file: $CFG_NEW"
  exit 4
fi

# sanity: config is valid json
if ! jq -e . "$CFG_NEW" >/dev/null 2>&1; then
  echo "[update-sub] generated config is not valid JSON. First 300 bytes:"
  head -c 300 "$CFG_NEW" || true
  exit 5
fi

echo "[update-sub] xray -test..."
if ! xray run -test -c "$CFG_NEW"; then
  echo "[update-sub] xray -test failed; keeping previous config"
  exit 6
fi

# apply only if changed
if [[ -f "$CFG" ]] && cmp -s "$CFG_NEW" "$CFG"; then
  echo "[update-sub] no changes"
  rm -f "$CFG_NEW"
  exit 0
fi

mv "$CFG_NEW" "$CFG"
touch "$RESTART_FLAG"
echo "[update-sub] updated config and requested restart"