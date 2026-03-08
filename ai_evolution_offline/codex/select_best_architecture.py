#!/usr/bin/env python3

import json

from architecture_pipeline import (
    adversarial_test_architecture,
    critique_architecture,
    load_candidate_variants,
    score_architecture_variant,
    select_best_architecture,
    simulate_player_behavior,
    solve_constraints,
)


if __name__ == "__main__":
    evaluated = []
    for variant in load_candidate_variants():
        critique = critique_architecture(variant)
        adversarial = adversarial_test_architecture(variant)
        simulation = simulate_player_behavior(variant)
        constraints = solve_constraints(variant, simulation)
        evaluated.append(
            {
                "variant": variant,
                "critique": critique,
                "adversarial": adversarial,
                "simulation": simulation,
                "constraints": constraints,
                "scores": score_architecture_variant(variant, critique, adversarial, simulation, constraints),
            }
        )
    print(json.dumps(select_best_architecture(evaluated), ensure_ascii=True, indent=2))
