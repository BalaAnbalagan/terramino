#!/usr/bin/env bash
set -euo pipefail
python3 -m pip install -q requests || true
python3 tests/functional/test_functional.py
