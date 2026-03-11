# Korean Player Feel Standard

## Purpose

This document defines the primary user-facing quality standard for MapleWorld from the perspective of a game-literate Korean player.

It exists to prevent the repository from over-claiming gameplay completion based only on automation closure, score stability, or data volume.

## Core Rule

Gameplay quality claims must be judged by whether the experience feels convincingly playable and worth returning to for a Korean player who enjoys MapleLand-style progression.

## Primary Evaluation Questions

- Does the first few minutes immediately pull the player in
- Do NPC lines and quest wording sound written for players rather than generated from a template
- Does the hunting loop have readable rhythm and visible reward anticipation
- Do regions feel familiar memorable and socially legible in a MapleLand-like way
- Does route pressure reward pressure and town return cadence feel satisfying
- Does the content avoid obvious placeholder or generated texture
- Does the session create a real desire to log in again

## Negative Signals

- dialogue that reads like schema filler
- quest summaries that describe structure but not lived motivation
- maps that feel interchangeable outside score differences
- rewards that are balanced but emotionally flat
- NPCs that function as switches rather than characters
- progression that is technically smooth but not memorable

## Repository Implication

When system-facing and player-facing interpretations disagree, MapleWorld should treat Korean player feel as the primary truth for gameplay completion claims.

## Completion Rule

`Automation 100%` and `gameplay 100%` are not the same claim.

Gameplay may be treated as `100%` only when a Korean MapleLand-literate player would no longer describe the world as:

- structurally solid but thin
- well-balanced but emotionally flat
- replayable in theory but not actually sticky
- populated by functional content rather than authored content

If economy rhythm, route memory, reward anticipation, or content density still feel materially behind MapleLand, gameplay completion should remain below `100%` even when the autonomy stack itself is closed.

The current live gameplay bottleneck should be treated as the next repair target until it is displaced by another higher-cost user-facing bottleneck.

## Conservative 100 Percent Rule

Gameplay `100%` should be judged conservatively.

The repository should assume that the player may later criticize:

- content thinness after the first hour
- repetition fatigue across longer sessions
- technically acceptable but emotionally weak dialogue or quest writing
- route and reward loops that are coherent but not memorable
- a world that is playable yet still lacks lived MapleLand texture

If those criticisms are still likely to be valid, MapleWorld should stay below `100%` even when current machine-visible gates are green.

## Audit Implication

Korean player-feel cannot be claimed from score stability alone.

The repository should keep machine-visible evidence for at least:

- placeholder NPC name and personality ratios
- placeholder dialogue ratios
- placeholder quest wording ratios
- Korean natural-language surface coverage in the active content set

If those remain heavily template-shaped, gameplay completion should not be marked as finished even when the autonomy loop itself is stable.
