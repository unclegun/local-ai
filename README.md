# Local Copilot Lite

Local Copilot Lite gives VS Code developers private, context-aware assistance for
ASP.NET Core Razor applications. Continue supplies the editor experience and local
project index. Three models run in Ollama inside Docker:

```text
VS Code + Continue
  |-- Plan / Chat / Edit ------ qwen3:8b
  |-- Inline autocomplete ---- qwen2.5-coder:1.5b-base
  `-- Codebase indexing ------ nomic-embed-text
               |
        127.0.0.1:11434
               |
     locked-down TCP bridge
               |
       Ollama internal network
```

No cloud model or MCP server is configured. Source and embeddings stay on the
workstation. “Project awareness” means Continue searches and retrieves relevant
code for each request; it does not place every file into every prompt.

## 1. Set up once

Requirements are Docker Desktop/Engine with Compose v2, VS Code with its `code`
command available, and enough free disk space for roughly 8 GB of models/images.
Keep Internet access available during first-time provisioning.

macOS/Linux:

```bash
cp .env.example .env
bash scripts/setup.sh
```

Windows PowerShell:

```powershell
Copy-Item .env.example .env
.\scripts\setup.ps1
```

Setup installs Continue when necessary, downloads only missing artifacts, installs
the local configuration with timestamped backups, enables indexing, starts Docker,
and waits for the local API to become healthy. Rerunning setup is safe and
preserves model data and Continue indexes.

Reload VS Code after setup. On Continue's first-run Ollama screen, click **Skip and
configure manually**, then choose **Local Copilot Lite** and **Local Project
Assistant**. The wizard's download choices are unnecessary because setup already
installed all three models.

## 2. Open a Razor project

Open the application's folder in VS Code. Continue creates its local index in the
user profile. Let the initial indexing activity finish before asking broad
repository questions. Indexing may briefly use CPU, especially on first open.

The global ignore file excludes `bin`, `obj`, `.vs`, dependency caches, minified
vendor assets, generated C#, secrets, and TFVC metadata. It retains `.cs`,
`.cshtml`, authored CSS/JavaScript, configuration, and application styling. Add a
project `.continueignore` only when an application has additional generated or
sensitive paths; it follows `.gitignore` syntax.

To refresh stale context, run **Developer: Reload Window**. Continue exposes index
status in its UI; the exact location varies by extension release. TFVC history and
diffs are unavailable because the on-prem TFVC service is not reachable from VS
Code. The assistant reasons from checked-out workspace files instead.

## 3. Use it

Use **Plan** for project-wide questions. Plan mode can list, search, and read files
automatically but blocks file edits. Good prompts include:

- “Trace authorization from the Razor page through policies, services, and data access. Cite each relevant file.”
- “Find every use of this permission and explain how access is granted or denied.”
- “Show which controller, page model, service, and view participate in this workflow.”
- “Review nullable-reference handling in this feature and rank concrete risks.”
- “Find the existing styling pattern for forms like this one and cite examples.”

Use **Chat** for explanations and design discussion. Indexed codebase retrieval is
available as context; use `@Codebase` when you want to force a retrieval pass in
Chat. Use **Edit** for a selected, reviewed change:

- “Refactor the selected handler to follow the pattern used by similar pages.”
- “Add server-side validation while preserving the existing RBAC behavior.”
- “Generate focused tests for this service, including authorization and null cases.”

Autocomplete uses the smaller model automatically while you type. Keep Continue's
tab-autocomplete setting enabled. Review every suggested change, especially RBAC,
authentication, configuration, and data-access changes.

The default workstation uses non-thinking `qwen3:8b` with an 8K context window.
Ollama loads one model at a time so chat, autocomplete, and indexing cannot exhaust
the default 8 GB Docker Desktop memory allocation. The index supplies the most
relevant project sections instead of placing the whole repository in one prompt.
The first request after model switching is slower while Docker loads the model.
CPU-only generation on Docker Desktop for Apple Silicon will be slower than a GPU
server; focused prompts produce the best experience.

## Daily commands

Start after Docker Desktop is running:

```bash
bash scripts/start.sh
```

```powershell
.\scripts\start.ps1
```

Check services, API health, and installed models:

```bash
bash scripts/status.sh
```

Use the corresponding `.ps1` scripts on Windows. Stop without removing models:

```bash
bash scripts/stop.sh
```

## Model and endpoint settings

`.env` controls the installation:

```text
RUNTIME_MODE=local
OLLAMA_API_BASE=http://127.0.0.1:11434
CHAT_MODEL=qwen3:8b
AUTOCOMPLETE_MODEL=qwen2.5-coder:1.5b-base
EMBED_MODEL=nomic-embed-text
```

After changing a model, rerun setup while connected. Shell environment variables
override `.env` values.

The future GPU-server hook is already present. Set `RUNTIME_MODE=remote` and
`OLLAMA_API_BASE` to the approved on-prem Ollama endpoint, then run setup. Remote
mode installs and tests the Continue profile without starting local Docker. The
server must already contain all configured models. TLS, authentication, firewall,
and GPU deployment are intentionally deferred until that server is designed.

## Air-gapped installation

On a connected staging workstation with the same Docker CPU architecture, obtain
an approved Continue VSIX and run:

```bash
bash scripts/create-offline-bundle.sh /path/to/continue.vsix
```

PowerShell:

```powershell
.\scripts\create-offline-bundle.ps1 -ContinueVsix C:\path\continue.vsix
```

The resulting `dist/local-copilot-lite-offline.tar.gz` contains this setup, the
architecture-specific Docker images, all three models, the VSIX, and SHA-256
checksums. Transfer it through the approved process. Setup verifies every payload
file before installation. On the disconnected workstation:

```bash
tar -xzf local-copilot-lite-offline.tar.gz
cd local-ai
bash scripts/setup.sh --offline-payload ../payload
```

Windows PowerShell after extracting the archive:

```powershell
Set-Location local-ai
.\scripts\setup.ps1 -OfflinePayload ..\payload
```

The installer rejects bundles built for a different Docker architecture. Runtime
uses a pinned Ollama image with `pull_policy: never`; Ollama is attached only to
the internal Docker network, and the API is published only on
`127.0.0.1:11434` through a constrained read-only TCP bridge. Container logs are
size-limited and rotated.

## Troubleshooting

```bash
docker compose -f compose.yml logs --tail 100
docker compose -f compose.yml restart
```

If port 11434 is occupied, stop the conflicting application rather than exposing
Ollama on `0.0.0.0`. If Continue produces a raw `read_file` JSON object, confirm
that **Local Project Assistant** is selected, reload VS Code, and start a new
conversation. If it tries to access
`/path/to/folder`, reload VS Code and start a new Continue conversation. The local
configuration directs directory listing to `.`—the root of the folder currently
open in VS Code—so you do not need to provide an absolute path. If results ignore
recent code, reload VS Code to refresh the index and verify the path is not
excluded.

If Continue reports `llama-server process has terminated: signal: killed`, Docker
ran out of memory. The included 8K, single-loaded-model profile is sized for
Docker Desktop's default 8 GB allocation. Reload VS Code after reinstalling the
configuration. For a larger context, increase Docker Desktop's memory first and
then raise `contextLength` cautiously; a 16K context adds about 2.3 GB of KV cache
to the 8B model.

Provisioning temporarily uses an Internet-connected Compose configuration, then
removes it without deleting `local-code-ai-models`. Normal runtime disables Ollama
cloud features and gives the Ollama container no ordinary outbound route.
