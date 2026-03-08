#!/usr/bin/env bash
set -euo pipefail

# Wave 1 wrapper for running a single Codex patch prompt.
#
# Intended use:
# - Validate local inputs before invoking Codex.
# - Keep command assembly repo-relative and deterministic.
# - Allow future bootstrap layers to extend profile/model policy safely.
#
# Intentionally deferred to later waves:
# - Queueing or worker loops
# - Automatic retries
# - Patch application policy beyond a single Codex invocation
# - Rich logging/event streaming conventions

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
env_script="${repo_root}/scripts/env/dev_env.sh"

if [ -f "$env_script" ]; then
  # shellcheck disable=SC1090
  source "$env_script"
fi

usage() {
  cat <<EOF
Usage: $(basename "$0") --patch-id PATCH_ID --prompt-file PATH [--output-file PATH]

Run one Codex patch prompt non-interactively from a prompt file.

Options:
  --patch-id ID        Logical patch identifier for operator visibility.
  --prompt-file PATH   File containing the patch prompt to send to Codex.
  --output-file PATH   Optional file for Codex's last message output.
  --help, -h           Show this help output and exit.

Notes:
  - The prompt file is passed to \`codex exec\` via stdin.
  - The wrapper runs from the repository root using \`codex exec -C\`.
  - This scaffold avoids undocumented Codex CLI flags.
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

if [ -z "$patch_id" ]; then
  echo "Missing required argument: --patch-id" >&2
  usage >&2
  exit 1
fi

if [ -z "$prompt_file" ]; then
  echo "Missing required argument: --prompt-file" >&2
  usage >&2
  exit 1
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "Missing required binary: codex" >&2
  echo "Install or expose the Codex CLI in PATH before using this wrapper." >&2
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

prompt_file_abs="$(cd "$(dirname "$prompt_file")" && pwd)/$(basename "$prompt_file")"

if [ -n "$output_file" ]; then
  output_dir="$(cd "$(dirname "$output_file")" && pwd)"
  if [ ! -d "$output_dir" ]; then
    echo "Output directory not found: $output_dir" >&2
    exit 1
  fi
  output_file_abs="${output_dir}/$(basename "$output_file")"
else
  output_file_abs=""
fi

cmd=(codex exec -C "$repo_root")

# Placeholder for future Wave 2+ policy:
# Keep command composition restricted to documented flags only.
# If profile selection becomes standardized, add it here after validation.
if [ -n "${CODEX_RUNNER_PROFILE:-}" ]; then
  cmd+=(-p "$CODEX_RUNNER_PROFILE")
fi

if [ -n "$output_file_abs" ]; then
  cmd+=(-o "$output_file_abs")
fi

# Prompt delivery uses documented stdin behavior via positional "-".
cmd+=(-)

echo "Patch ID: $patch_id"
echo "Repo root: $repo_root"
echo "Prompt file: $prompt_file_abs"
if [ -n "$output_file_abs" ]; then
  echo "Output file: $output_file_abs"
fi

"${cmd[@]}" < "$prompt_file_abs"
