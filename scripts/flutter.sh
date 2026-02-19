#!/usr/bin/env bash
set -euo pipefail

# Local Flutter SDK pinned inside this repo (not committed)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT_DIR/.flutter/bin/flutter" "$@"
