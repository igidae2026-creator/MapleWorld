#!/usr/bin/env bash
set -euo pipefail

# Wave 1 bounded parallel worker scaffold.
#
# Intended use:
# - Start a fixed number of worker processes for the first N valid queue entries.
# - Wait for all started workers and return a non-zero code if any worker fails.
#
# Intentionally deferred to later waves:
# - Dynamic scaling
# - Shared queue claiming/locking
# - Long-running supervision
# - Fair scheduling and retries

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
env_script="${repo_root}/scripts/env/dev_env.sh"
worker_script="${repo_root}/scripts/codex/worker.sh"

if [ -f "$env_script" ]; then
  # shellcheck disable=SC1090
  source "$env_script"
fi

usage() {
  cat <<EOF
Usage: $(basename "$0") --queue-file PATH [--workers N]

Start up to N one-shot workers for the first valid entries in a conservative queue file.

Options:
  --queue-file PATH    Required queue file path.
  --workers N          Maximum number of workers to start. Default: 2.
  --help, -h           Show this help output and exit.

Queue format:
  PATCH_ID<TAB>PROMPT_FILE<TAB>OUTPUT_FILE(optional)
EOF
}

queue_file=""
workers=2

while [ "$#" -gt 0 ]; do
  case "$1" in
    --queue-file)
      queue_file="${2-}"
      shift 2
      ;;
    --workers)
      workers="${2-}"
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

if [ -z "$queue_file" ]; then
  echo "Missing required argument: --queue-file" >&2
  usage >&2
  exit 1
fi

case "$workers" in
  ''|*[!0-9]*)
    echo "--workers must be a positive integer." >&2
    exit 1
    ;;
esac

if [ "$workers" -le 0 ]; then
  echo "--workers must be greater than zero." >&2
  exit 1
fi

if [ ! -f "$queue_file" ]; then
  echo "Queue file not found: $queue_file" >&2
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

pids=()
started=0

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

  cmd=(bash "$worker_script" --patch-id "$patch_id" --prompt-file "$prompt_file")
  if [ -n "${output_file:-}" ]; then
    cmd+=(--output-file "$output_file")
  fi

  echo "Starting worker for patch: $patch_id"
  "${cmd[@]}" &
  pids+=("$!")
  started=$((started + 1))

  if [ "$started" -ge "$workers" ]; then
    break
  fi
done < "$queue_file"

if [ "$started" -eq 0 ]; then
  echo "No valid patch descriptors were started from queue: $queue_file" >&2
  exit 1
fi

status=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    status=1
  fi
done

exit "$status"
