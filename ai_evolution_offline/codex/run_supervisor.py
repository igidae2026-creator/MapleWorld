#!/usr/bin/env python3

from __future__ import annotations

import json

from design_pipeline import CYCLE_LOG_PATH, SCORE_TARGETS, append_jsonl, choose_emphasis_domains, load_progress, score_candidates, update_progress
from run_generation_cycle import run_generation_cycle


def main() -> None:
    max_cycles = 12
    cycle = 0
    stalled_cycles = 0
    last_score_signature = None

    while cycle < max_cycles:
        score_candidates()
        progress = update_progress()
        current_signature = (
            progress.get("structure_pipeline_score"),
            progress.get("asset_throughput_score"),
            progress.get("live_balance_quality_score"),
            progress.get("mapleland_similarity_score"),
            progress.get("overall_efficiency_score"),
        )

        if progress.get("project_complete") or all(progress.get(key, 0.0) >= SCORE_TARGETS[key] for key in SCORE_TARGETS):
            print(
                json.dumps(
                    {
                        "status": "complete",
                        "progress": progress,
                        "emphasis_domains": choose_emphasis_domains(weakest_dimension=progress.get("weakest_dimension")),
                    },
                    ensure_ascii=True,
                    indent=2,
                )
            )
            return

        if current_signature == last_score_signature:
            stalled_cycles += 1
        else:
            stalled_cycles = 0
        if stalled_cycles >= 3:
            print(
                json.dumps(
                    {
                        "status": "stalled",
                        "progress": progress,
                        "emphasis_domains": choose_emphasis_domains(weakest_dimension=progress.get("weakest_dimension")),
                    },
                    ensure_ascii=True,
                    indent=2,
                )
            )
            raise SystemExit(1)

        cycle += 1
        weakest_dimension = str(progress.get("weakest_dimension", "structure_pipeline_score"))
        emphasis_domains = choose_emphasis_domains(weakest_dimension=weakest_dimension)
        append_jsonl(
            CYCLE_LOG_PATH,
            {
                "phase": "supervisor_dispatch",
                "cycle": cycle,
                "weakest_dimension": weakest_dimension,
                "emphasis_domains": emphasis_domains,
                "scores": current_signature,
            },
        )
        run_generation_cycle(emphasis_domains=emphasis_domains, weakest_dimension=weakest_dimension)
        last_score_signature = current_signature

    progress = load_progress()
    print(json.dumps({"status": "max_cycles_reached", "progress": progress}, ensure_ascii=True, indent=2))
    raise SystemExit(1)


if __name__ == "__main__":
    main()
