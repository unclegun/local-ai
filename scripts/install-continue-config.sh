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
api_base=${OLLAMA_API_BASE:-$(value_from_env_file OLLAMA_API_BASE)}
chat_model=${chat_model:-qwen3:8b}
autocomplete_model=${autocomplete_model:-qwen2.5-coder:1.5b-base}
embed_model=${embed_model:-nomic-embed-text}
api_base=${api_base:-http://127.0.0.1:11434}

for model in "$chat_model" "$autocomplete_model" "$embed_model"; do
  [[ "$model" =~ ^[a-zA-Z0-9._:/-]+$ ]] || { echo "Invalid model name: $model" >&2; exit 1; }
done
[[ "$api_base" =~ ^https?://[^[:space:]]+$ ]] || { echo 'OLLAMA_API_BASE must be an HTTP(S) URL.' >&2; exit 1; }

directory="${HOME}/.continue"
mkdir -p "$directory"
stamp=$(date +%Y%m%d-%H%M%S)
for name in config.yaml .continueignore .continuerc.json; do
  if [ -f "$directory/$name" ]; then
    cp "$directory/$name" "$directory/$name.backup.$stamp"
  fi
done

temporary="$directory/config.yaml.tmp.$$"
trap 'rm -f "$temporary"' EXIT
sed \
  -e "s|^    model: qwen3:8b$|    model: $chat_model|" \
  -e "s|^    model: qwen2.5-coder:1.5b-base$|    model: $autocomplete_model|" \
  -e "s|^    model: nomic-embed-text$|    model: $embed_model|" \
  -e "s|apiBase: http://127.0.0.1:11434|apiBase: $api_base|g" \
  continue/config.yaml > "$temporary"
mv "$temporary" "$directory/config.yaml"
cp continue/continueignore "$directory/.continueignore"
cp continue/continuerc.json "$directory/.continuerc.json"

echo "Installed Continue configuration at $directory/config.yaml"
echo "Chat: $chat_model | Autocomplete: $autocomplete_model | Embeddings: $embed_model"
echo "Endpoint: $api_base"
