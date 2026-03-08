#!/usr/bin/env python3

import json

from architecture_pipeline import run_architecture_supervisor


if __name__ == "__main__":
    print(json.dumps(run_architecture_supervisor(), ensure_ascii=True, indent=2))
