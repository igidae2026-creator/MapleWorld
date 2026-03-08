#!/usr/bin/env python3

import json

from architecture_pipeline import (
    adversarial_test_architecture,
    critique_architecture,
    load_candidate_variants,
    mutate_architecture,
    simulate_player_behavior,
    solve_constraints,
)


if __name__ == "__main__":
    mutated = []
    for variant in load_candidate_variants():
        critique = critique_architecture(variant)
        adversarial = adversarial_test_architecture(variant)
        simulation = simulate_player_behavior(variant)
        constraints = solve_constraints(variant, simulation)
        mutated.append(mutate_architecture(variant, critique, adversarial, constraints))
    print(json.dumps(mutated, ensure_ascii=True, indent=2))
