#!/usr/bin/env bash
set -euo pipefail

# Wave 1 patch queue polling scaffold.
#
# Conservative queue format for now:
# - Plain text file
# - One descriptor per line
# - Tab-separated fields:
#     PATCH_ID<TAB>PROMPT_FILE<TAB>OUTPUT_FILE(optional)
# - Blank lines and lines beginning with # are ignored
#
# Intentionally deferred to later waves:
# - Locking/claiming semantics
# - State transitions for queued/running/completed
# - Database or durable queue backends
# - Automatic looping; this script is one-shot only

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
env_script="${repo_root}/scripts/env/dev_env.sh"
worker_script="${repo_root}/ai_evolution_offline/codex/worker.sh"

if [ -f "$env_script" ]; then
  # shellcheck disable=SC1090
  source "$env_script"
fi

usage() {
  cat <<EOF
Usage: $(basename "$0") [--queue-file PATH] [--max-items N] [--dispatch-first]

Inspect a conservative Wave 1 patch queue file and optionally dispatch the first valid entry.

Options:
  --queue-file PATH    Queue file to read.
                       Default: .codex/patch_queue.tsv under the repo root.
  --max-items N        Maximum number of valid queue entries to print. Default: 20.
  --dispatch-first     Run the first valid queue entry through worker.sh.
  --help, -h           Show this help output and exit.
EOF
}

queue_file="${repo_root}/.codex/patch_queue.tsv"
max_items=20
dispatch_first=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --queue-file)
      queue_file="${2-}"
      shift 2
      ;;
    --max-items)
      max_items="${2-}"
      shift 2
      ;;
    --dispatch-first)
      dispatch_first=1
      shift 1
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

case "$max_items" in
  ''|*[!0-9]*)
    echo "--max-items must be a positive integer." >&2
    exit 1
    ;;
esac

if [ "$max_items" -eq 0 ]; then
  echo "--max-items must be greater than zero." >&2
  exit 1
fi

if [ ! -f "$queue_file" ]; then
  echo "Queue file not found: $queue_file" >&2
  echo "Create it when your queue format is ready. Expected Wave 1 format is tab-separated text." >&2
  exit 1
fi

if [ ! -r "$queue_file" ]; then
  echo "Queue file is not readable: $queue_file" >&2
  exit 1
fi

if [ ! -f "$worker_script" ]; then
  echo "Worker script not found: $worker_script" >&2
  exit 1
fi

valid_count=0
first_patch_id=""
first_prompt_file=""
first_output_file=""

while IFS=$'\t' read -r patch_id prompt_file output_file extra || [ -n "${patch_id:-}" ]; do
  if [ -z "${patch_id:-}" ]; then
    continue
  fi

  case "$patch_id" in
    \#*)
      continue
      ;;
  esac

  if [ -n "${extra:-}" ]; then
    echo "Skipping queue line with unsupported extra fields: $patch_id" >&2
    continue
  fi

  if [ -z "${prompt_file:-}" ]; then
    echo "Skipping queue line missing prompt file for patch: $patch_id" >&2
    continue
  fi

  if [ ! -f "$prompt_file" ]; then
    echo "Skipping queue line with missing prompt file: $prompt_file" >&2
    continue
  fi

  valid_count=$((valid_count + 1))
  printf 'PATCH_ID=%s\tPROMPT_FILE=%s' "$patch_id" "$prompt_file"
  if [ -n "${output_file:-}" ]; then
    printf '\tOUTPUT_FILE=%s' "$output_file"
  fi
  printf '\n'

  if [ -z "$first_patch_id" ]; then
    first_patch_id="$patch_id"
    first_prompt_file="$prompt_file"
    first_output_file="${output_file:-}"
  fi

  if [ "$valid_count" -ge "$max_items" ]; then
    break
  fi
done < "$queue_file"

if [ "$valid_count" -eq 0 ]; then
  echo "No valid patch descriptors found in queue: $queue_file" >&2
  exit 1
fi

if [ "$dispatch_first" -eq 1 ]; then
  cmd=(bash "$worker_script" --patch-id "$first_patch_id" --prompt-file "$first_prompt_file")
  if [ -n "$first_output_file" ]; then
    cmd+=(--output-file "$first_output_file")
  fi

  echo "Dispatching first valid queue item: $first_patch_id"
  "${cmd[@]}"
fi

