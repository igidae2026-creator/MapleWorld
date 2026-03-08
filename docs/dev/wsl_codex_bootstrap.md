# Wave 1 WSL and Codex Bootstrap

This guide documents the current Wave 1 developer bootstrap scaffold for MapleWorld.

Wave 1 covers:
- WSL development environment checks
- development environment bootstrap
- Codex single-patch runner scaffold
- single-task worker scaffold
- conservative patch queue scaffold
- Makefile entrypoints for the above

Wave 1 does not cover runtime stability or gameplay systems. The following are explicitly out of scope here:
- gameplay
- combat
- economy
- quests
- party, guild, and social systems

## Prerequisites

Wave 1 assumes a local repository checkout with these repo-relative areas present:
- `data/`
- `msw_runtime/`
- `offline_ops/`
- `ai_evolution_offline/`
- `scripts/`
- `tests/`

Baseline tools expected by the WSL setup scaffold:
- `bash`
- `git`
- `node`
- `npm`
- `make`
- `codex` for Codex-specific flows

The current scaffolds are conservative by design:
- they do not install packages automatically
- they do not assume `sudo` will succeed
- they do not configure shell profiles
- they do not claim queue or worker orchestration is production-ready

## Files in Wave 1

WSL setup:
- `scripts/dev/setup_wsl_env.sh`

Development env bootstrap:
- `scripts/env/dev_env.sh`
- `.env.example`

Codex runner and workers:
- `ai_evolution_offline/codex/run_patch.sh`
- `ai_evolution_offline/codex/worker.sh`
- `ai_evolution_offline/codex/poll_patch_queue.sh`
- `ai_evolution_offline/codex/parallel_workers.sh`

Makefile entrypoints:
- `Makefile`

Documentation:
- `docs/dev/wsl_codex_bootstrap.md`

## Setup Steps

### 1. Verify the WSL baseline

Run:

```bash
bash scripts/dev/setup_wsl_env.sh
```

Or through `make`:

```bash
make setup-wsl
```

What this checks:
- whether the environment appears to be WSL
- whether the repository contains `data/`, `msw_runtime/`, `offline_ops/`, `ai_evolution_offline/`, `scripts/`, and `tests/`
- whether `bash`, `git`, `node`, `npm`, and `make` are available

What it intentionally leaves manual:
- package installation
- version-manager choice for Node.js
- `sudo`-based setup
- shell customization

### 2. Prepare a local development `.env`

Use the example file as a template:

```bash
cp .env.example .env
```

Review and adjust placeholders only if needed for local development:
- `MAPLELAND_DEV_MODE`
- `MAPLELAND_WSL_EXPECTED`
- `MAPLELAND_NODE_ENV`
- `MAPLELAND_LOCAL_PORT`
- `CODEX_RUNNER_PROFILE`
- `CODEX_BOOTSTRAP_MODE`

Do not place real secrets in `.env` for Wave 1.

### 3. Load the development environment

Source the bootstrap script:

```bash
source scripts/env/dev_env.sh
```

To print the current Wave 1 environment values:

```bash
bash -lc 'source scripts/env/dev_env.sh --print'
```

Or through `make`:

```bash
make env-check
```

Wave 1 behavior of `scripts/env/dev_env.sh`:
- resolves the repo root relative to the script
- exports development-oriented variables only
- loads `.env` conservatively through an allowlist
- skips unsupported or non-Wave-1 variables

## Codex Runner Scaffold

### Intent

`ai_evolution_offline/codex/run_patch.sh` is a wrapper for one non-interactive Codex patch prompt.

It validates:
- `codex` is on `PATH`
- the prompt file exists and is readable
- the optional output directory exists

### Important CLI note

Wave 1 intentionally documents the Codex invocation through the wrapper, not as a guaranteed raw CLI contract for future waves.

Current wrapper behavior:
- runs from the repository root
- uses `codex exec`
- passes the prompt file on standard input
- optionally writes the last Codex message to a file
- optionally passes the profile from `CODEX_RUNNER_PROFILE`

Use the wrapper instead of depending on direct CLI composition in your own scripts unless the CLI contract is explicitly revalidated.

### Example

Assuming a prompt file exists at `prompts/patches/PATCH-001.md`:

```bash
bash ai_evolution_offline/codex/run_patch.sh \
  --patch-id PATCH-001 \
  --prompt-file prompts/patches/PATCH-001.md \
  --output-file .codex/logs/PATCH-001.last.txt
```

Or through `make`:

```bash
make codex-run-patch ARGS='--patch-id PATCH-001 --prompt-file prompts/patches/PATCH-001.md --output-file .codex/logs/PATCH-001.last.txt'
```

## Worker Scaffold

`ai_evolution_offline/codex/worker.sh` is a one-shot wrapper around `ai_evolution_offline/codex/run_patch.sh`.

It does not:
- poll continuously
- retry failed work
- claim queue items
- coordinate with other workers

Example:

```bash
bash ai_evolution_offline/codex/worker.sh \
  --patch-id PATCH-001 \
  --prompt-file prompts/patches/PATCH-001.md \
  --output-file .codex/logs/PATCH-001.last.txt
```

Or:

```bash
make codex-worker ARGS='--patch-id PATCH-001 --prompt-file prompts/patches/PATCH-001.md --output-file .codex/logs/PATCH-001.last.txt'
```

## Patch Queue Scaffold

### Queue format

Wave 1 uses a simple placeholder queue format so it can be replaced later without heavy migration:

- plain text file
- one descriptor per line
- tab-separated fields
- blank lines ignored
- lines beginning with `#` ignored

Current format:

```text
PATCH_ID<TAB>PROMPT_FILE<TAB>OUTPUT_FILE(optional)
```

Example queue file content:

```text
# patch queue
PATCH-001	prompts/patches/PATCH-001.md	.codex/logs/PATCH-001.last.txt
PATCH-002	prompts/patches/PATCH-002.md	.codex/logs/PATCH-002.last.txt
```

The default queue path used by `ai_evolution_offline/codex/poll_patch_queue.sh` is:

```text
.codex/patch_queue.tsv
```

This file is not auto-created by Wave 1.

### Inspect the queue

```bash
bash ai_evolution_offline/codex/poll_patch_queue.sh --queue-file .codex/patch_queue.tsv --max-items 10
```

Or:

```bash
make codex-poll-queue ARGS='--queue-file .codex/patch_queue.tsv --max-items 10'
```

### Dispatch the first valid queue item

```bash
bash ai_evolution_offline/codex/poll_patch_queue.sh --queue-file .codex/patch_queue.tsv --dispatch-first
```

This is bounded and one-shot. It does not remove the item from the queue and does not mark state.

## Parallel Worker Scaffold

`ai_evolution_offline/codex/parallel_workers.sh` starts a fixed number of one-shot workers from the first valid queue entries, then waits for them to finish.

Example:

```bash
bash ai_evolution_offline/codex/parallel_workers.sh --queue-file .codex/patch_queue.tsv --workers 2
```

Or:

```bash
make codex-workers ARGS='--queue-file .codex/patch_queue.tsv --workers 2'
```

Wave 1 limitations:
- no slot refilling after a worker finishes
- no queue locking
- no duplicate prevention across operators
- no scheduling fairness

## Makefile Entrypoints

Wave 1 includes these operator-facing `make` targets:
- `make setup-wsl`
- `make env-check`
- `make codex-run-patch ARGS='...'`
- `make codex-worker ARGS='...'`
- `make codex-workers ARGS='...'`
- `make codex-poll-queue ARGS='...'`

These are intentionally thin wrappers around the scripts and should be treated as convenience entrypoints, not as a full task system.

## Validation Checks

Basic validation sequence:

```bash
make setup-wsl
make env-check
bash ai_evolution_offline/codex/run_patch.sh --help
bash ai_evolution_offline/codex/worker.sh --help
bash ai_evolution_offline/codex/poll_patch_queue.sh --help
bash ai_evolution_offline/codex/parallel_workers.sh --help
```

If you have a prompt file and queue file prepared, a practical Wave 1 smoke path is:

```bash
bash ai_evolution_offline/codex/run_patch.sh --patch-id PATCH-001 --prompt-file prompts/patches/PATCH-001.md
```

## Known Placeholders in Wave 1

- The Codex wrapper documents wrapper behavior first and leaves raw CLI composition intentionally conservative.
- `CODEX_RUNNER_PROFILE` is passed through if present, but profile policy is not standardized yet.
- The queue file format is tab-separated text only as a temporary scaffold.
- Queue item claiming, locking, deduplication, and completion tracking are not implemented.
- Parallel worker execution is bounded to the first valid `N` entries and does not act as a daemon.
- `.env` loading is allowlisted to Wave 1 development variables only.
- Output files are treated as optional last-message sinks, not structured logs.

## Troubleshooting

### `setup_wsl_env.sh` reports missing tools

Install the missing tools manually for your distro. If `sudo` is unavailable, use your environment's package-management process instead of forcing installation through the script.

### `make env-check` works but your shell does not retain variables

`make env-check` runs in a subprocess and only prints the values. To keep them in your current shell, run:

```bash
source scripts/env/dev_env.sh
```

### `run_patch.sh` says `codex` is missing

Ensure the Codex CLI is installed and available on `PATH` in the shell where you run the command.

### Queue polling finds no valid entries

Check that:
- the queue file exists
- each line uses tab separators, not spaces
- each prompt file path exists relative to the repository or as a valid readable path

### Parallel workers do not process the whole queue

That is expected in Wave 1. `ai_evolution_offline/codex/parallel_workers.sh` only launches the first valid `N` entries and waits for them. It is not a scheduler.

## Limitations and Deferred Items

Wave 1 is bootstrap scaffolding only. It should not be treated as proof of:
- stable runtime orchestration
- durable queue semantics
- production-safe worker concurrency
- validated Codex automation beyond the documented wrappers

Future waves can replace or extend the queue format, worker coordination model, and Codex invocation policy without promising backward compatibility for ad hoc local wrappers.
