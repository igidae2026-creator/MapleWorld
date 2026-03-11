# Goal

MapleWorld must be governed by a top-level autonomous skeleton under MapleStory Worlds constraints before further lower-level governance sprawl.

## Immediate Objective

Implement the following repository-level skeleton as top authority for MapleWorld:

- `L0  RULE_CARDS`
- `L1  METAOS_CONSTITUTION`
- `L2  CHECKLIST_LAYER1_목표조건`
- `L3  CHECKLIST_LAYER2_모듈책임`
- `L4  CHECKLIST_LAYER3_REPO매핑`
- `L5  CHECKLIST_METHOD_패치`
- `A1  COVERAGE_AUDIT`
- `A2  CONFLICT_LOG`

## Enforcement Intent

- If a governance rule can be placed in the top skeleton, put it there.
- Do not create new interim or subordinate governance frameworks that will later be replaced by this skeleton.
- Existing lower-level canonical files may remain as implementation/reference artifacts, but authority must flow from the skeleton above them.

## Current Delivery Bias

1. Establish the top skeleton.
2. Map MapleWorld runtime, content, evaluation, and patch flow into that skeleton.
3. Let autonomous loops operate under the skeleton instead of inventing new local rules.
4. Only then continue bottleneck repair and feature evolution.

## Ultimate Automation Target

MapleWorld must evolve toward 24-hour high-quality autonomous operation with near-zero required human quality lift.

The target is not merely autonomous execution inside already-approved scope. The target is a system where:

- repeated loops keep producing high-quality outputs without human steering
- human intervention produces little or no additional quality gain in normal cycles
- new external materials, references, and inputs can be screened automatically for scope fit, authority fit, and upgrade value
- qualifying new materials can be promoted automatically into the repository's governed evolution flow instead of waiting for manual sorting

MapleWorld is not complete while autonomy is limited to only the currently included repository surface.

## Final Threshold Rule

MapleWorld should judge its final upper-bound state through one bundled evaluation rather than scattered local readiness claims.

That common evaluation shape is defined in `UNIVERSAL_FINAL_THRESHOLD_BUNDLE.md`.

## Korean Player-Feel Rule

MapleWorld should judge gameplay completion and percentage claims from the perspective of a game-literate Korean player rather than only from system closure or data coverage.

The reference definition for that perspective is fixed in `docs/standards/KOREAN_PLAYER_FEEL_STANDARD.md`.

When the repository reports gameplay quality or completion percentage it should weight the following as primary user-facing truth:

- whether the first few minutes pull the player in immediately
- whether NPC dialogue and quest wording feel natural in Korean rather than template-generated
- whether the hunt loop has readable rhythm and live reward anticipation
- whether regions feel familiar memorable and socially legible in a MapleLand-like way
- whether route pressure reward pressure and town return cadence feel satisfying rather than merely balanced
- whether the content avoids obvious generated-placeholder texture
- whether the player feels a real urge to log in again after one session

System completeness without that player-facing feel is not sufficient to claim high gameplay completion.

## Gameplay 100 Percent Rule

MapleWorld must not claim `100% complete` from automation closure, threshold closure, or stable governance alone.

For gameplay completion, `100%` means:

- a Korean player who likes MapleLand no longer feels a meaningful overall quality deficit versus MapleLand
- first-session pull, hunt rhythm, route memory, reward anticipation, town return cadence, and replay desire hold together as one convincing game experience
- NPCs, quests, rewards, and route pressure feel authored rather than template-generated
- the economy loop feels readable, satisfying, and self-consistent rather than merely safe
- content density is high enough that the world no longer feels like a thin but well-governed skeleton

MapleWorld should use a conservative interpretation of that claim.

Gameplay is not `100%` if a likely future Korean-player criticism is still materially valid, including:

- "the structure is solid but the content is still thin"
- "the balance is safer than before but the emotional reward rhythm is still flat"
- "the early game is good but long-session repetition shows too quickly"
- "the language is natural enough but not memorable enough"
- "the world is playable but still does not carry MapleLand-level lived texture"

In other words, `100%` must already include the most probable later user criticisms, not merely the issues already made explicit during current repair cycles.

Until that bar is met, MapleWorld may report `automation 100%` or `final threshold bundle ready`, but it must not treat those as equivalent to gameplay completion.

Current repository priority is therefore:

1. preserve `MSW final threshold` closure
2. raise `MapleLand-parity gameplay completion`
3. treat the highest-cost live player bottleneck as the next repair target

Current live player bottleneck is `economy_coherence` until another user-facing gate becomes more expensive.

The preferred repair order for that bottleneck is:

1. map-scoped role-band rebalance
2. next-map coupled rebalance
3. cross-band coupled rebalance
4. routing and selection-pressure repair
5. only then broader content-density expansion

## Content Acceleration Rule

MapleWorld should not pursue content completion primarily through manual one-off content authoring.

The preferred acceleration path is:

1. fixed level-band content templates
2. generator-driven candidate production
3. early quality-gate rejection
4. promotion of only passing candidates

The main purpose of autonomy upgrades is not only faster output volume.

The main purpose is to prevent repeated production of weak candidates and reduce wasted iteration.

When this path is working correctly, MapleWorld should expect substantial schedule compression for content completion, with a practical target reduction on the order of `30%` to `60%` versus weaker manual-first iteration.
