#!/usr/bin/env python3

import json

from architecture_pipeline import score_selected_architecture


if __name__ == "__main__":
    print(json.dumps(score_selected_architecture(), ensure_ascii=True, indent=2))
