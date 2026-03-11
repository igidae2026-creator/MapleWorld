# AUTONOMY_TARGET

## Purpose

This document isolates the autonomy and quality bar for the repository.
It defines the unattended execution standard separately from broader design or governance goals.

## Target Standard

- The target is a 24-hour autonomous loop that keeps producing high-quality outputs with minimal human micromanagement.
- Human involvement is allowed, but it must not be required for routine continuation.
- The desired steady state is that human intervention adds little or no meaningful quality gain over the system's default output.
- Human involvement should progressively shift from active production to approval, audit, and rare correction.
- Automation limited only to already-included scope is not enough; the outer loop must also evaluate newly arriving material, decide whether it belongs in scope, and promote it automatically when it clears quality and relevance gates.
- The system should continuously raise, reject, defer, or promote work items and source material without waiting for manual triage.

## Evaluation Gate

- If the system still depends on frequent operator steering to maintain design quality, the target has not yet been met.
- Simulation, mutation, scoring, selection, batching, and writeback decisions should be judged by unattended operation without quality collapse.
- Quality gates should prefer deterministic reruns, low review noise, shard safety, and no append-style degradation of canonical outputs.
- If newly ingested material still needs a person to decide routine scope selection, prioritization, or promotion into the active loop, the target has not yet been met.

## Operational Implications

- Persist intent, progress, and resume state in repository files instead of relying on chat memory.
- Prefer resumable loops, manifests, ledgers, state checkpoints, and scored artifacts over conversational continuation.
- Treat automation changes as suspect if they increase dependence on manual steering.
- Favor replayable architecture evolution over one-off operator-driven design passes.
- Add an outer ingestion and triage layer that can classify new inputs, bind them to the right subsystem, and either reject, sandbox, or promote them without operator involvement.
- Judge autonomy progress against the stricter bar of "human intervention produces negligible additional quality gain," not merely "the existing loop runs unattended."
