#!/usr/bin/env python3

import json

from architecture_pipeline import generate_architecture_variants


if __name__ == "__main__":
    print(json.dumps(generate_architecture_variants(), ensure_ascii=True, indent=2))
