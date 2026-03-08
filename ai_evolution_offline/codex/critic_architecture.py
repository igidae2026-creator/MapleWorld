#!/usr/bin/env python3

import json

from architecture_pipeline import critique_architecture, load_candidate_variants


if __name__ == "__main__":
    print(
        json.dumps(
            [critique_architecture(variant) for variant in load_candidate_variants()],
            ensure_ascii=True,
            indent=2,
        )
    )
