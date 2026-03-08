#!/usr/bin/env bash
set -euo pipefail

# Wave 1 development environment bootstrap for MapleWorld.
#
# Intended use:
# - Source from local shell sessions or helper scripts.
# - Establish repo-relative development variables.
# - Optionally load a conservative subset of values from .env.
#
# Intentionally deferred to later waves:
# - Secrets and credentials
# - Production-only configuration
# - Toolchain installation and PATH mutation
# - Runtime-specific service endpoints beyond local placeholders

_mapleland_dev_env_sourced=0
if [ "${BASH_SOURCE[0]}" != "$0" ]; then
  _mapleland_dev_env_sourced=1
fi

_mapleland_dev_env_return() {
  local status="${1:-0}"
  if [ "$_mapleland_dev_env_sourced" -eq 1 ]; then
    return "$status"
  fi
  exit "$status"
}

_mapleland_dev_env_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_mapleland_repo_root="$(cd "${_mapleland_dev_env_script_dir}/../.." && pwd)"
_mapleland_env_file="${MAPLELAND_ENV_FILE:-${_mapleland_repo_root}/.env}"

_mapleland_log() {
  printf '%s\n' "$*"
}

_mapleland_warn() {
  printf 'WARNING: %s\n' "$*" >&2
}

_mapleland_is_allowed_env_key() {
  case "$1" in
    MAPLELAND_DEV_MODE|MAPLELAND_WSL_EXPECTED|MAPLELAND_NODE_ENV|MAPLELAND_LOCAL_PORT|CODEX_RUNNER_PROFILE|CODEX_BOOTSTRAP_MODE)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

_mapleland_strip_wrapping_quotes() {
  local value="$1"

  if [[ "$value" =~ ^\".*\"$ ]]; then
    value="${value#\"}"
    value="${value%\"}"
  elif [[ "$value" =~ ^\'.*\'$ ]]; then
    value="${value#\'}"
    value="${value%\'}"
  fi

  printf '%s' "$value"
}

_mapleland_load_dotenv() {
  local file="$1"
  local line
  local key
  local value

  if [ ! -f "$file" ]; then
    return 0
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|'#'*)
        continue
        ;;
    esac

    if [[ "$line" != *=* ]]; then
      _mapleland_warn "skipping malformed .env line: $line"
      continue
    fi

    key="${line%%=*}"
    value="${line#*=}"

    if [[ ! "$key" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
      _mapleland_warn "skipping unsupported .env key: $key"
      continue
    fi

    if ! _mapleland_is_allowed_env_key "$key"; then
      _mapleland_warn "skipping non-Wave-1 variable from .env: $key"
      continue
    fi

    value="$(_mapleland_strip_wrapping_quotes "$value")"
    export "$key=$value"
  done < "$file"
}

export MAPLELAND_REPO_ROOT="${_mapleland_repo_root}"
export MAPLELAND_ENV_FILE="${_mapleland_env_file}"

# Wave 1 defaults stay development-only and repo-local.
export MAPLELAND_DEV_MODE="${MAPLELAND_DEV_MODE:-1}"
export MAPLELAND_WSL_EXPECTED="${MAPLELAND_WSL_EXPECTED:-1}"
export MAPLELAND_NODE_ENV="${MAPLELAND_NODE_ENV:-development}"
export MAPLELAND_LOCAL_PORT="${MAPLELAND_LOCAL_PORT:-3000}"
export CODEX_RUNNER_PROFILE="${CODEX_RUNNER_PROFILE:-local}"
export CODEX_BOOTSTRAP_MODE="${CODEX_BOOTSTRAP_MODE:-wave1}"

_mapleland_load_dotenv "${MAPLELAND_ENV_FILE}"

if [ "${1-}" = "--print" ]; then
  _mapleland_log "MAPLELAND_REPO_ROOT=${MAPLELAND_REPO_ROOT}"
  _mapleland_log "MAPLELAND_ENV_FILE=${MAPLELAND_ENV_FILE}"
  _mapleland_log "MAPLELAND_DEV_MODE=${MAPLELAND_DEV_MODE}"
  _mapleland_log "MAPLELAND_WSL_EXPECTED=${MAPLELAND_WSL_EXPECTED}"
  _mapleland_log "MAPLELAND_NODE_ENV=${MAPLELAND_NODE_ENV}"
  _mapleland_log "MAPLELAND_LOCAL_PORT=${MAPLELAND_LOCAL_PORT}"
  _mapleland_log "CODEX_RUNNER_PROFILE=${CODEX_RUNNER_PROFILE}"
  _mapleland_log "CODEX_BOOTSTRAP_MODE=${CODEX_BOOTSTRAP_MODE}"
fi

unset -f _mapleland_log
unset -f _mapleland_warn
unset -f _mapleland_is_allowed_env_key
unset -f _mapleland_strip_wrapping_quotes
unset -f _mapleland_load_dotenv
unset -f _mapleland_dev_env_return
unset _mapleland_dev_env_script_dir
unset _mapleland_repo_root
unset _mapleland_dev_env_sourced

