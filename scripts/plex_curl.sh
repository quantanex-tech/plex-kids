#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cd app
#   ../scripts/plex_curl.sh owner
#   ../scripts/plex_curl.sh switch <homeUserId>
#   ../scripts/plex_curl.sh server <token>
#
# Reads app/.env (flutter_dotenv style) for PLEX_BASE_URL and PLEX_TOKEN.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/app/.env"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$ENV_FILE")
fi

: "${PLEX_BASE_URL:?PLEX_BASE_URL missing (set in app/.env e.g. http://192.168.1.50:32400)}"
: "${PLEX_TOKEN:?PLEX_TOKEN missing (set in app/.env)}"

cmd="${1:-}"

owner_checks() {
  echo "== Owner token: identity =="
  curl -iS "$PLEX_BASE_URL/identity?X-Plex-Token=$PLEX_TOKEN" | head -n 20
  echo
  echo "== Owner token: library/sections =="
  curl -iS "$PLEX_BASE_URL/library/sections?X-Plex-Token=$PLEX_TOKEN" | head -n 20
}

switch_user() {
  local user_id="$1"
  echo "== plex.tv switch user $user_id =="

  # plex.tv requires standard Plex client headers for the switch endpoint.
  local client_id="${PLEX_CLIENT_IDENTIFIER:-plex-kids-dev}"

  curl -sS -X POST \
    -H "X-Plex-Product: Plex Kids" \
    -H "X-Plex-Version: 0.0.1" \
    -H "X-Plex-Device: Android" \
    -H "X-Plex-Platform: Android" \
    -H "X-Plex-Device-Name: plex-kids" \
    -H "X-Plex-Client-Identifier: ${client_id}" \
    "https://plex.tv/api/home/users/${user_id}/switch?X-Plex-Token=${PLEX_TOKEN}" | head -c 600
  echo
  echo "(Look for authenticationToken=\"...\")"
}

server_with_token() {
  local token="$1"
  echo "== Server: library/sections with provided token =="
  curl -iS "$PLEX_BASE_URL/library/sections?X-Plex-Token=$token" | head -n 20
}

case "$cmd" in
  owner)
    owner_checks
    ;;
  switch)
    [[ $# -ge 2 ]] || { echo "Usage: $0 switch <homeUserId>"; exit 2; }
    switch_user "$2"
    ;;
  server)
    [[ $# -ge 2 ]] || { echo "Usage: $0 server <token>"; exit 2; }
    server_with_token "$2"
    ;;
  *)
    echo "Usage: $0 {owner|switch <homeUserId>|server <token>}" >&2
    exit 2
    ;;
esac
