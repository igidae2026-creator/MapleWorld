#!/usr/bin/env bash
set -euo pipefail

# Wave 1 single-task worker scaffold.
#
# Intended use:
# - Execute one assigned patch via scripts/codex/run_patch.sh.
# - Validate prompt and output paths before handing control to Codex.
#
# Intentionally deferred to later waves:
# - Queue claiming/locking
# - Retries and backoff
# - Structured status reporting
# - Cross-worker coordination

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
env_script="${repo_root}/scripts/env/dev_env.sh"
design_prompt="${repo_root}/ops/codex_design_prompt.md"

if [ -f "$env_script" ]; then
  # shellcheck disable=SC1090
  source "$env_script"
fi

usage() {
  cat <<EOF
Usage: $(basename "$0") --patch-id PATCH_ID --prompt-file PATH [--output-file PATH]

Run a single patch assignment through scripts/codex/run_patch.sh.

Options:
  --patch-id ID        Required logical patch identifier.
  --prompt-file PATH   Required prompt file path.
  --output-file PATH   Optional last-message output file path.
  --help, -h           Show this help output and exit.
EOF
}

patch_id=""
prompt_file=""
output_file=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --patch-id)
      patch_id="${2-}"
      shift 2
      ;;
    --prompt-file)
      prompt_file="${2-}"
      shift 2
      ;;
    --output-file)
      output_file="${2-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$patch_id" ] || [ -z "$prompt_file" ]; then
  echo "Both --patch-id and --prompt-file are required." >&2
  usage >&2
  exit 1
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "Missing required binary: codex" >&2
  exit 1
fi

if [ ! -f "$design_prompt" ]; then
  echo "Design prompt not found: $design_prompt" >&2
  exit 1
fi

if [ ! -f "$prompt_file" ]; then
  echo "Prompt file not found: $prompt_file" >&2
  exit 1
fi

if [ ! -r "$prompt_file" ]; then
  echo "Prompt file is not readable: $prompt_file" >&2
  exit 1
fi

echo "Worker dispatching patch: $patch_id"

cd "$repo_root"

echo "Running Codex design expansion..."

codex exec --full-auto "$(cat "$design_prompt")"

bash scripts/codex/update_progress.sh
