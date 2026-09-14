#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
vsix=${1:-}
output=${2:-dist/local-copilot-lite-offline.tar.gz}
[ -f "$vsix" ] || { echo 'Usage: create-offline-bundle.sh PATH/continue.vsix [OUTPUT.tar.gz]' >&2; exit 2; }

bash scripts/provision.sh
stage=$(mktemp -d /tmp/local-copilot-bundle.XXXXXX)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/local-ai" "$stage/payload"
tar --exclude='./.git' --exclude='./.env' --exclude='./dist' -cf - . | tar -C "$stage/local-ai" -xf -
cp "$vsix" "$stage/payload/continue.vsix"
docker save -o "$stage/payload/docker-images.tar" \
  ollama/ollama@sha256:684d8674b4315fa18f4f0e973a118ec2652ed96f67563277839985175858e0ba \
  alpine/socat:1.8.0.3
docker run --rm --entrypoint tar -v local-code-ai-models:/models -v "$stage/payload:/payload" alpine/socat:1.8.0.3 -C /models -cf /payload/models.tar .
printf 'DOCKER_ARCH=%s\n' "$(docker version --format '{{.Server.Arch}}')" > "$stage/payload/manifest.env"
if command -v shasum >/dev/null; then
  (cd "$stage/payload" && shasum -a 256 continue.vsix docker-images.tar models.tar manifest.env > SHA256SUMS)
elif command -v sha256sum >/dev/null; then
  (cd "$stage/payload" && sha256sum continue.vsix docker-images.tar models.tar manifest.env > SHA256SUMS)
else
  echo 'A SHA-256 tool (shasum or sha256sum) is required.' >&2
  exit 1
fi
mkdir -p "$(dirname "$output")"
tar -C "$stage" -czf "$output" local-ai payload
echo "Created $output"
echo 'On the matching offline workstation: extract it, cd local-ai, then run scripts/setup.sh --offline-payload ../payload'
