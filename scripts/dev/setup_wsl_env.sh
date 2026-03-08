#!/usr/bin/env bash
set -euo pipefail

# Conservative WSL development environment scaffold for MapleWorld.
#
# Intended use:
# - Verify a baseline WSL shell environment for local development.
# - Confirm the repository layout looks correct.
# - Point the developer at manual remediation steps when tools are missing.
#
# Intentional limitations:
# - Does not install packages automatically.
# - Does not assume sudo is available or functional.
# - Does not modify repo configuration, shell profiles, or user-specific paths.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

missing_tools=()
warnings=()

usage() {
  cat <<EOF
Usage: $(basename "$0") [--help] [--quiet]

Verify a conservative WSL development baseline for the MapleWorld repository.

Options:
  --help   Show this help output and exit.
  --quiet  Reduce non-essential output. Warnings and summary are still shown.

What this script checks:
  - Whether the current environment appears to be WSL.
  - Whether the repo root contains expected directories:
    data/, msw/, ops/, scripts/, tests/
  - Whether baseline development tools are available:
    bash, git, node, npm, make

What this script intentionally leaves manual:
  - Installing missing packages
  - Choosing Node/npm version managers
  - System package updates and sudo-based setup
  - Shell profile customization

Exit status:
  0 if all baseline checks pass
  1 if one or more checks need attention
EOF
}

quiet=0
case "${1-}" in
  "")
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  --quiet)
    quiet=1
    ;;
  *)
    echo "Unknown argument: ${1}" >&2
    echo >&2
    usage >&2
    exit 1
    ;;
esac

say() {
  if [ "$quiet" -eq 0 ]; then
    printf '%s\n' "$*"
  fi
}

warn() {
  warnings+=("$*")
  printf 'WARNING: %s\n' "$*" >&2
}

check_repo_dir() {
  local dir_name="$1"
  local dir_path="${repo_root}/${dir_name}"

  if [ -d "$dir_path" ]; then
    say "[ok] repo directory present: ${dir_name}/"
  else
    warn "expected repo directory missing: ${dir_name}/"
  fi
}

read_version() {
  local tool="$1"

  case "$tool" in
    bash)
      bash --version | head -n 1
      ;;
    git)
      git --version
      ;;
    node)
      node --version
      ;;
    npm)
      npm --version
      ;;
    make)
      make --version | head -n 1
      ;;
    *)
      printf 'version command not defined for %s\n' "$tool"
      ;;
  esac
}

check_tool() {
  local tool="$1"

  if command -v "$tool" >/dev/null 2>&1; then
    say "[ok] tool found: $(read_version "$tool")"
  else
    missing_tools+=("$tool")
    warn "missing tool: ${tool}"
  fi
}

print_manual_guidance() {
  local tool

  if [ "${#missing_tools[@]}" -eq 0 ]; then
    return
  fi

  cat <<'EOF'

Manual guidance for missing tools:
  - If your distro uses apt and sudo works, a common pattern is:
      sudo apt update
      sudo apt install -y git nodejs npm make
  - If sudo is unavailable, use your distro's package manager manually or ask for system access.
  - For Node.js, prefer your team's expected version source before installing:
      nvm, fnm, asdf, distro packages, or project documentation
EOF

  for tool in "${missing_tools[@]}"; do
    case "$tool" in
      bash)
        echo "  - bash: verify your WSL distro includes Bash and that your shell starts correctly."
        ;;
      git)
        echo "  - git: install Git through your distro package manager."
        ;;
      node)
        echo "  - node: install a project-appropriate Node.js version."
        ;;
      npm)
        echo "  - npm: usually installed with Node.js, but package layouts vary by distro."
        ;;
      make)
        echo "  - make: often provided by the 'make' package or build-essential/meta-packages."
        ;;
    esac
  done
}

say "MapleWorld WSL environment check"
say "Repo root: ${repo_root}"

if grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null; then
  say "[ok] WSL environment detected"
else
  warn "this does not appear to be WSL based on /proc/version"
fi

for dir_name in data msw ops scripts tests; do
  check_repo_dir "$dir_name"
done

for tool in bash git node npm make; do
  check_tool "$tool"
done

if [ "${#missing_tools[@]}" -eq 0 ]; then
  say "[ok] baseline tools are available"
fi

print_manual_guidance

echo
echo "Summary:"
echo "  Checks performed: WSL detection, repo layout, bash/git/node/npm/make"
echo "  Manual by design: package installation, sudo flows, version-manager selection, shell customization"

if [ "${#warnings[@]}" -eq 0 ]; then
  echo "  Result: baseline checks passed"
  exit 0
fi

echo "  Result: attention needed (${#warnings[@]} warning(s))"
exit 1
