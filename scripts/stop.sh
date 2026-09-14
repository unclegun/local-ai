#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
docker compose -f compose.yml down
echo 'Stopped. The local-code-ai-models volume is preserved.'
