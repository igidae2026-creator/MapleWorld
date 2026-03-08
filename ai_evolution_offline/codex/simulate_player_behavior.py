#!/usr/bin/env python3

import json

from architecture_pipeline import load_candidate_variants, simulate_player_behavior


if __name__ == "__main__":
    print(
        json.dumps(
            [simulate_player_behavior(variant) for variant in load_candidate_variants()],
            ensure_ascii=True,
            indent=2,
        )
    )
