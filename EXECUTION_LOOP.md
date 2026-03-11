# Execution Loop

This document is the canonical development loop for MapleWorld.

The repository does not optimize for maximum feature throughput. It optimizes for the fastest path to a stronger player experience floor.

## North-Star Gates

All major work must improve one or more of these gates from `QUALITY_GATES.md`:

- `first_10_minutes`
- `first_hour_retention`
- `day1_return_intent`

If a task does not plausibly improve a gate, reduce risk against a gate, or preserve a gate while enabling the next patch, it is not a priority task.

## Bottleneck-First Principle

Do not ask "what feature should we add next?"

Ask:

1. Which single player-experience bottleneck is currently cutting the most value?
2. What is the smallest patch set that can remove or reduce that bottleneck?
3. How do we verify that the bottleneck actually improved?

Broad feature expansion is secondary to bottleneck removal.

## Canonical Loop

1. Read the latest player-experience gates and score outputs.
2. Select the highest-cost bottleneck affecting first 10 minutes, first hour, or Day-1 return intent.
3. Build a narrow patch set touching only the files required to move that bottleneck.
4. Run deterministic tests, simulations, and proxy metrics.
5. Reject any patch that regresses canon locks, variance floors, economy stability, authority boundaries, or player-experience gates.
6. Prefer the smallest surviving patch with the strongest player-experience gain.
7. Merge the winner, record the result, and repeat.

## Autonomy Core

MapleWorld should not stop at a single supervisor loop plus a mutable state file.

The preferred execution core is:

1. append-only event log
2. typed state snapshots
3. typed job queue
4. supervisor orchestration

with a policy layer above them.

This is the recommended path from bounded background automation toward 24-hour high-quality autonomous operation.

## Outer-Autonomy Requirement

The execution loop is incomplete if it only operates on materials already inside repository scope.

The loop must evolve to support:

- external material intake
- scope-fit classification
- authority-fit classification
- upgrade-value classification
- automatic promotion of qualified materials into the governed loop
- automatic rejection of low-value or out-of-scope materials

Human sorting should become an exception, not the default.

## Preferred Runtime Shape

Recommended execution architecture:

- `event log` for append-only machine history
- `typed snapshots` for fast current-state reads
- `job queue` for explicit autonomous work units
- `supervisor` for dispatch, retry, rollback, and escalation
- `policy layer` for scope and promotion decisions

See `AUTONOMY_STACK.md` for the target structure.

## Role Split

`GPT-5.x` should focus on:

- bottleneck identification
- patch framing
- critique and adversarial review
- gate interpretation
- priority selection

`Codex` should focus on:

- local code and data mutation
- test additions
- simulation reruns
- regression repair
- winner integration

`Python` should own:

- scoring
- simulation
- merge decisions
- mutation selection
- progress tracking

## Branching Rules

- Branch only when the current bottleneck plateaus or two plausible fixes conflict.
- Keep branch count low.
- Branches must compete on the same bottleneck and the same acceptance gates.
- Kill branches quickly if they do not outperform the baseline.

## Scope Control

When time pressure is high, cut breadth before cutting player feel.

Prefer:

- fewer maps with better role separation
- fewer bosses with stronger identity
- fewer progression branches with cleaner incentives
- fewer economy surfaces with better stability

Avoid:

- wide content additions that do not change player-experience gates
- speculative subsystem rewrites without a measured bottleneck
- broad system churn that increases merge cost

## Merge Standard

A patch is a candidate winner only if it:

- preserves runtime boundary rules
- preserves canon and variance rules
- keeps deterministic validation green
- improves or protects the active player-experience bottleneck
- does not create a larger downstream bottleneck than the one it solves

## Default Bias

The default bias is:

`player-experience bottleneck removal > feature breadth > architectural elegance`

Architectural work remains necessary, but it should be justified by a blocked gate, a repeated bottleneck, or a recurring regression family.
