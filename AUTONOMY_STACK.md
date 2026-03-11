# Autonomy Stack

MapleWorld should evolve from a single background loop into a supervisor-centered autonomous operating stack.

## Core Recommendation

Do not stop at:

- supervisor loop
- one mutable state file
- one background runner

Use this core instead:

1. `event log`
2. `typed snapshots`
3. `job queue`
4. `supervisor`

Layer `policy` on top of those four.

## Why This Is Better

The older loop-plus-state-file model is enough for bounded repetition inside already-known scope, but it is weak at:

- replaying or auditing why a decision happened
- separating retry logic from domain logic
- handling multiple concurrent autonomy surfaces
- screening and promoting new external materials
- preventing stale state and drift across long-running cycles

The recommended stack improves all five.

## Core Components

### 1. Event Log

Use an append-only event stream as the machine history of autonomy.

It should record:

- job creation
- job claims
- job completion
- gate failures
- patch application
- regression detection
- external material intake
- promotion or rejection decisions

Preferred repository target:

- `offline_ops/autonomy/events.jsonl`

### 2. Typed Snapshots

Use typed current-state snapshots instead of one generic mutable state file.

Separate state by meaning:

- active bottleneck
- queued jobs
- running jobs
- last successful patch
- regression state
- promotion candidates
- external intake state
- system health

Preferred repository target:

- `offline_ops/autonomy/state/*.json`

### 3. Job Queue

Represent autonomous work as typed jobs rather than implicit loop phases.

Minimum job classes:

- `analyze_bottleneck`
- `propose_patch`
- `apply_patch`
- `verify_patch`
- `ingest_external_material`
- `classify_external_material`
- `promote_material`
- `repair_regression`

Preferred repository target:

- `offline_ops/autonomy/jobs/queued/`
- `offline_ops/autonomy/jobs/running/`
- `offline_ops/autonomy/jobs/done/`
- `offline_ops/autonomy/jobs/failed/`

### 4. Supervisor

The supervisor owns orchestration, not domain scoring.

It should:

- claim and dispatch jobs
- enforce retry budgets
- stop repeated fake progress
- trigger rollback or repair
- escalate when policy blocks automatic promotion
- keep long-running background autonomy bounded and auditable

Preferred repository target:

- `offline_ops/autonomy/supervisor.py`

## Policy Layer

The policy layer decides what the system is allowed to do.

It should judge:

- scope fit
- authority fit
- patch eligibility
- promotion eligibility
- human-approval requirements
- rollback requirements

This layer is mandatory for the outer-autonomy target because new materials cannot be trusted by default.

Preferred repository target:

- `offline_ops/autonomy/policy.py`
- `offline_ops/autonomy/policy_rules.json`

## Outer-Autonomy Requirement

MapleWorld is not done when automation only operates on already-included repository materials.

The autonomy stack must eventually support:

- intake of new files, notes, references, and datasets
- automatic scope classification
- automatic authority classification
- automatic promotion or rejection
- bounded insertion into the governed repository loop

That outer loop is required for 24-hour high-quality autonomy.

## Acceptance Standard

The stack is approaching its goal only when:

- the system runs for long periods without stale-state drift
- bottleneck selection, patching, and verification remain auditable
- new external materials can be screened automatically
- qualified materials can be promoted without manual sorting
- human intervention adds little or no quality gain in normal operation

## Final Threshold Evaluation

The autonomy stack should evaluate final-threshold readiness through one bundled machine-readable surface rather than disconnected local flags.

That bundled standard is defined in `UNIVERSAL_FINAL_THRESHOLD_BUNDLE.md`.
