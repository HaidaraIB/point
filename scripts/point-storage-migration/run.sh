#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [[ ! -f .env ]]; then
  echo "Missing .env — copy .env.example and fill in secrets."
  exit 1
fi

if [[ ! -d node_modules ]]; then
  echo "Running npm install…"
  npm install
fi

exec node migrate.mjs "$@"
