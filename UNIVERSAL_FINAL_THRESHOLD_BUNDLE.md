# Universal Final Threshold Bundle

MapleWorld must evaluate its MSW final upper bound through one bundled decision, not through separate local readiness claims.

## Output Contract

Each evaluation cycle must emit one authoritative artifact:

- `offline_ops/codex_state/final_threshold_eval.json`

That artifact must contain at least:

- `final_threshold_ready`
- `failed_criteria`
- `blocking_evidence`
- `next_required_repairs`
- `quality_lift_if_human_intervenes`

## Required Criteria

The bundle is ready only when all of the following hold at once:

1. closed loop completion
   - task creation -> execution -> failure record -> next task continuation is machine-closed
2. quality gate fail-closed behavior
   - weak results, invalid scope, and unsafe patches are auto-rejected or held
3. append-only truth and replayability
   - append-only logs, lineage, replayability, and checkpoint history remain intact
4. MSW constraint preservation
   - no external backend
   - server-authoritative play preserved
   - room/world/channel/instance/topology boundaries preserved
5. progression and routing stability
   - level-band progression, field ladder, route variance, social density, congestion routing stay stable
6. economy control stability
   - economy coherence, meso velocity control, sink/faucet pressure, consumable burn, rare supply throttling stay stable
7. live-ops and rollback stability
   - intervention plane, override plane, rollback boundary, replay boundary stay stable
8. fault and input absorption
   - new faults and new inputs are automatically held, rejected, repaired, recovered, or promoted
9. long-soak steady-state behavior
   - long soak keeps steady/noop dominant without renewed instability
10. negligible human quality lift
   - human intervention adds little or no meaningful quality gain
11. scoped intake and promotion
   - new content, operating materials, patch candidates, and external materials are processed inside scope, authority, and policy

## Automation Requirement

The system must run this bundle once per cycle.

If the bundle is not ready:

- record failed criteria in the artifact
- record blocking evidence in the artifact
- generate only the missing repair work as follow-up queue items

If the bundle is ready:

- do not invent new threshold sub-goals for the same cycle
- keep the bundle artifact as the single upper-bound readiness decision
