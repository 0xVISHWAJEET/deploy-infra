#!/usr/bin/env bash
# Starts (or updates) the shared gateway Caddy on this host. Run from the production
# server itself: ./deploy.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Starting/updating the shared gateway"
docker compose up -d

echo "==> Waiting for it to answer"
healthy=false
for i in $(seq 1 15); do
  if curl -fsS -o /dev/null "http://localhost:8888/"; then
    healthy=true
    break
  fi
  sleep 2
done
if [ "$healthy" != "true" ]; then
  echo "==> Gateway did not respond on :8888 after 30s — check container logs" >&2
  docker compose ps
  exit 1
fi

echo "==> Gateway live at http://localhost:8888/ — see Caddyfile for configured paths"
