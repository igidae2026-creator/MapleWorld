#!/usr/bin/env python3

import json

from design_pipeline import choose_emphasis_domains, load_progress


if __name__ == "__main__":
    print(
        json.dumps(
            {
                "status": "stub",
                "message": "Local pipeline remains authoritative; cloud batch generation can consume data/tmp candidate files.",
                "emphasis_domains": choose_emphasis_domains(),
                "progress": load_progress(),
            },
            ensure_ascii=True,
            indent=2,
        )
    )
