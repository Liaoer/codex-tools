#!/bin/sh
set -eu

DATA_DIR="${CODEX_TOOLS_PROXY_DATA_DIR:-/data}"
ACCOUNTS_FILE="${DATA_DIR}/accounts.json"

if [ ! -s "${ACCOUNTS_FILE}" ]; then
  echo "error: ${ACCOUNTS_FILE} is missing or empty." >&2
  echo "hint: copy a codex-tools accounts.json into /data before starting proxyd." >&2
  echo "hint: on Merlin + DockRoot the host mount should usually be /tmp/mnt/sda1/codex-proxyd-data:/data" >&2
  exit 64
fi

exec /usr/local/bin/codex-tools-proxyd serve \
  --data-dir "${DATA_DIR}" \
  --host 0.0.0.0 \
  --port 8787 \
  --no-sync-current-auth
