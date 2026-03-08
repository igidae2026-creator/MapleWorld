.PHONY: setup-wsl env-check codex-run-patch codex-worker codex-workers codex-poll-queue

# Wave 1 bootstrap entrypoints.
# These targets are intentionally thin wrappers around the repository scripts.

setup-wsl:
	@test -f scripts/dev/setup_wsl_env.sh || { echo "Missing script: scripts/dev/setup_wsl_env.sh"; exit 1; }
	@bash scripts/dev/setup_wsl_env.sh

env-check:
	@test -f scripts/env/dev_env.sh || { echo "Missing script: scripts/env/dev_env.sh"; exit 1; }
	@bash -lc 'source scripts/env/dev_env.sh --print'

codex-run-patch:
	@test -f scripts/codex/run_patch.sh || { echo "Missing script: scripts/codex/run_patch.sh"; exit 1; }
	@bash scripts/codex/run_patch.sh $(ARGS)

codex-worker:
	@test -f scripts/codex/worker.sh || { echo "Missing script: scripts/codex/worker.sh"; exit 1; }
	@bash scripts/codex/worker.sh $(ARGS)

codex-workers:
	@test -f scripts/codex/parallel_workers.sh || { echo "Missing script: scripts/codex/parallel_workers.sh"; exit 1; }
	@bash scripts/codex/parallel_workers.sh $(ARGS)

codex-poll-queue:
	@test -f scripts/codex/poll_patch_queue.sh || { echo "Missing script: scripts/codex/poll_patch_queue.sh"; exit 1; }
	@bash scripts/codex/poll_patch_queue.sh $(ARGS)
