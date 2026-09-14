#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

offline_payload=''
if [ "${1:-}" = '--offline-payload' ]; then
  offline_payload=${2:-}
  [ -d "$offline_payload" ] || { echo 'Usage: setup.sh [--offline-payload PATH]' >&2; exit 2; }
fi

command -v docker >/dev/null || { echo 'Docker is required.' >&2; exit 1; }
docker compose version >/dev/null || { echo 'Docker Compose v2 is required.' >&2; exit 1; }
command -v code >/dev/null || { echo 'VS Code command-line tool (code) is required.' >&2; exit 1; }

if [ ! -f .env ]; then cp .env.example .env; echo 'Created .env from workstation defaults.'; fi
runtime_mode=$(sed -n 's/^[[:space:]]*RUNTIME_MODE[[:space:]]*=[[:space:]]*//p' .env | tail -n 1)
runtime_mode=${RUNTIME_MODE:-${runtime_mode:-local}}

if [ -n "$offline_payload" ]; then
  offline_payload=$(cd "$offline_payload" && pwd)
  [ -f "$offline_payload/SHA256SUMS" ] || { echo 'Offline bundle is missing SHA256SUMS.' >&2; exit 1; }
  if command -v shasum >/dev/null; then
    (cd "$offline_payload" && shasum -a 256 -c SHA256SUMS) || { echo 'Offline bundle checksum verification failed.' >&2; exit 1; }
  elif command -v sha256sum >/dev/null; then
    (cd "$offline_payload" && sha256sum -c SHA256SUMS) || { echo 'Offline bundle checksum verification failed.' >&2; exit 1; }
  else
    echo 'A SHA-256 tool (shasum or sha256sum) is required.' >&2
    exit 1
  fi
  expected_arch=$(sed -n 's/^DOCKER_ARCH=//p' "$offline_payload/manifest.env")
  actual_arch=$(docker version --format '{{.Server.Arch}}')
  [ "$expected_arch" = "$actual_arch" ] || { echo "Bundle architecture $expected_arch does not match Docker $actual_arch." >&2; exit 1; }
  docker compose -f compose.yml down
  docker load -i "$offline_payload/docker-images.tar"
  docker volume create local-code-ai-models >/dev/null
  docker run --rm --entrypoint tar -v local-code-ai-models:/models -v "$offline_payload:/payload:ro" alpine/socat:1.8.0.3 -C /models -xf /payload/models.tar
  code --install-extension "$offline_payload/continue.vsix" --force
elif ! code --list-extensions | grep -qi '^continue\.continue$'; then
  if [ -n "${CONTINUE_VSIX:-}" ] && [ -f "$CONTINUE_VSIX" ]; then
    code --install-extension "$CONTINUE_VSIX" --force
  else
    code --install-extension Continue.continue
  fi
fi

if [ "$runtime_mode" = local ]; then
  if [ -z "$offline_payload" ]; then bash scripts/provision.sh; fi
  bash scripts/install-continue-config.sh
  bash scripts/start.sh
elif [ "$runtime_mode" = remote ]; then
  bash scripts/install-continue-config.sh
  api_base=$(sed -n 's/^[[:space:]]*OLLAMA_API_BASE[[:space:]]*=[[:space:]]*//p' .env | tail -n 1)
  curl --noproxy '*' -fsS --max-time 10 "${api_base%/}/api/tags" >/dev/null || { echo "Remote Ollama is unavailable at $api_base" >&2; exit 1; }
  echo "Remote profile installed for $api_base. Local Docker runtime was not started."
else
  echo 'RUNTIME_MODE must be local or remote.' >&2
  exit 1
fi

echo 'Setup complete. Reload VS Code, choose Local Copilot Lite, and use Plan mode for project-wide questions.'
