#!/usr/bin/env python3

import json

from design_pipeline import score_candidates


if __name__ == "__main__":
    print(json.dumps(score_candidates(), ensure_ascii=True, indent=2))
