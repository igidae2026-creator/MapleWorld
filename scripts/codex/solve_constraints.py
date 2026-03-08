#!/usr/bin/env python3

import json

from architecture_pipeline import load_candidate_variants, simulate_player_behavior, solve_constraints


if __name__ == "__main__":
    results = []
    for variant in load_candidate_variants():
        simulation = simulate_player_behavior(variant)
        results.append(solve_constraints(variant, simulation))
    print(json.dumps(results, ensure_ascii=True, indent=2))
