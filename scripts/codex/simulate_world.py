#!/usr/bin/env python3

import json

from design_pipeline import record_simulation_result


if __name__ == "__main__":
    print(json.dumps(record_simulation_result(), ensure_ascii=True, indent=2))
