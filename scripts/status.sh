#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
docker compose -f compose.yml ps
curl --noproxy '*' -fsS --max-time 5 http://127.0.0.1:11434/ >/dev/null || {
  echo 'Local Copilot Lite is not reachable. Run: bash scripts/start.sh' >&2
  exit 1
}
printf 'API: ready\n'
docker exec local-code-ai-ollama ollama list
