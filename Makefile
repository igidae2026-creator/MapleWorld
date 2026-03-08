.PHONY: setup-wsl env-check test codex-run-patch codex-worker codex-workers codex-poll-queue

# Wave 1 bootstrap entrypoints.
# These targets are intentionally thin wrappers around the repository scripts.

setup-wsl:
	@test -f scripts/dev/setup_wsl_env.sh || { echo "Missing script: scripts/dev/setup_wsl_env.sh"; exit 1; }
	@bash scripts/dev/setup_wsl_env.sh

env-check:
	@test -f scripts/env/dev_env.sh || { echo "Missing script: scripts/env/dev_env.sh"; exit 1; }
	@bash -lc 'source scripts/env/dev_env.sh --print'

test:
	@test -f scripts/run_tests.sh || { echo "Missing script: scripts/run_tests.sh"; exit 1; }
	@bash scripts/run_tests.sh

codex-run-patch:
	@test -f ai_evolution_offline/codex/run_patch.sh || { echo "Missing script: ai_evolution_offline/codex/run_patch.sh"; exit 1; }
	@bash ai_evolution_offline/codex/run_patch.sh $(ARGS)

codex-worker:
	@test -f ai_evolution_offline/codex/worker.sh || { echo "Missing script: ai_evolution_offline/codex/worker.sh"; exit 1; }
	@bash ai_evolution_offline/codex/worker.sh $(ARGS)

codex-workers:
	@test -f ai_evolution_offline/codex/parallel_workers.sh || { echo "Missing script: ai_evolution_offline/codex/parallel_workers.sh"; exit 1; }
	@bash ai_evolution_offline/codex/parallel_workers.sh $(ARGS)

codex-poll-queue:
	@test -f ai_evolution_offline/codex/poll_patch_queue.sh || { echo "Missing script: ai_evolution_offline/codex/poll_patch_queue.sh"; exit 1; }
	@bash ai_evolution_offline/codex/poll_patch_queue.sh $(ARGS)
