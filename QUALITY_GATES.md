# Quality Gates

This document defines the canonical player-experience floor for MapleWorld.

These gates are proxies. They are not direct player truth, but they are the hard floor the autonomous loop must protect.

## Primary Gates

### `first_10_minutes`

The first session must establish:

- immediate combat readability
- obvious near-term goals
- at least one clear upgrade or reward expectation
- enough movement and map change to imply world scale
- no confusing dead time that looks like missing content

Fail patterns:

- unclear next step
- flat early rewards
- no visible route distinction
- no memorable early spike
- combat that feels like placeholder throughput

### `first_hour_retention`

The first hour must establish:

- repeated growth beats instead of a single opening burst
- route choice between safe, alternative, and contested value
- clear equipment or build direction
- enough economy pressure to make drops and mesos matter
- at least one visible social hook such as party value, boss goal, or trade relevance

Fail patterns:

- one optimal route dominates
- upgrades arrive too slowly or too uniformly
- economy pressure is invisible
- quests and hunting do not connect
- map changes do not alter tactics or reward logic

### `day1_return_intent`

By the end of the first long session, the player should leave with:

- unfinished progression goals
- one or more chase rewards or chase maps
- at least one short-term social or boss objective
- confidence that returning creates meaningful progress

Fail patterns:

- progression plateau with no visible unlock target
- reward structure too flat to create anticipation
- social systems present but not valuable
- bosses exist but do not matter
- item replacement pressure collapses too early

## Secondary Protection Gates

These do not replace the primary gates. They protect them.

### `economy_coherence`

- meso faucets and sinks stay legible
- potion and repair pressure remain relevant
- rare supply remains throttled
- trade surfaces do not erase field value

### `route_variance`

- each major band preserves route-role separation
- canon-locked identity is preserved
- memorable reward spikes survive optimization

### `social_density`

- party play has real payoff windows
- shared spaces remain meaningful
- congestion routing relieves pressure without deleting visibility

### `authority_safety`

- gameplay remains server-authoritative
- save, rollback, and replay boundaries stay explicit
- anti-abuse hooks continue to protect reward mutation

## Acceptance Rule

The loop must reject patches that improve raw stability, architecture clarity, or throughput while damaging:

- `first_10_minutes`
- `first_hour_retention`
- `day1_return_intent`
- route variance
- canon locks

## Triage Rule

When multiple weak areas exist, prioritize them in this order:

1. `first_10_minutes`
2. `first_hour_retention`
3. `day1_return_intent`
4. `economy_coherence`
5. `route_variance`
6. `social_density`
7. `authority_safety`

## Measurement Expectations

Offline metrics, tests, and simulations should increasingly emit machine-readable proxies for these gates.

Until full proxies exist, reviewers and autonomous prompts should still frame critique in these terms instead of broad statements like "improve gameplay" or "add content."
