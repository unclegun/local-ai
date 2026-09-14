#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# Remove any interrupted provisioning deployment before starting offline.
docker compose -f compose.provision.yml down
docker compose -f compose.yml up -d --wait
for ((i=0; i<60; i++)); do
  if curl --noproxy '*' -fsS --max-time 2 http://127.0.0.1:11434/ >/dev/null; then
    echo 'Local Copilot Lite is ready at http://127.0.0.1:11434.'
    exit 0
  fi
  sleep 2
done
echo 'Ollama did not respond locally; inspect docker compose logs.' >&2
exit 1
