#!/usr/bin/env bash

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "$REPO_ROOT"

python3 scripts/codex/update_progress.py
