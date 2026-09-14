#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

value_from_env_file() {
  local key=$1 value=''
  if [ -f .env ]; then
    value=$(sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" .env | tail -n 1)
  fi
  printf '%s' "$value"
}

chat_model=${CHAT_MODEL:-$(value_from_env_file CHAT_MODEL)}
autocomplete_model=${AUTOCOMPLETE_MODEL:-$(value_from_env_file AUTOCOMPLETE_MODEL)}
embed_model=${EMBED_MODEL:-$(value_from_env_file EMBED_MODEL)}
chat_model=${chat_model:-qwen3:8b}
autocomplete_model=${autocomplete_model:-qwen2.5-coder:1.5b-base}
embed_model=${embed_model:-nomic-embed-text}

for model in "$chat_model" "$autocomplete_model" "$embed_model"; do
  [[ "$model" =~ ^[a-zA-Z0-9._:/-]+$ ]] || { echo "Invalid model name: $model" >&2; exit 1; }
done

echo 'Provisioning uses Internet access only for artifacts that are not already cached.'
trap 'docker compose -f compose.provision.yml down' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

docker compose -f compose.yml down
if ! docker image inspect alpine/socat:1.8.0.3 >/dev/null 2>&1; then
  docker pull alpine/socat:1.8.0.3
fi
docker compose -f compose.provision.yml up -d --wait

installed=$(docker compose -f compose.provision.yml exec -T ollama ollama list)
for model in "$chat_model" "$autocomplete_model" "$embed_model"; do
  if printf '%s\n' "$installed" | awk -v wanted="$model" 'BEGIN {tagged = wanted ~ /:/ ? wanted : wanted ":latest"} NR>1 && ($1==wanted || $1==tagged) {found=1} END {exit !found}'; then
    echo "Already installed: $model"
  else
    docker compose -f compose.provision.yml exec -T ollama ollama pull "$model"
    installed=$(docker compose -f compose.provision.yml exec -T ollama ollama list)
  fi
done

printf '%s\n' "$installed"
echo 'Provisioning succeeded. The connected container will be removed; model data is preserved.'
