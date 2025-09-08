#!/usr/bin/env bash
set -euo pipefail
TARGET="${TARGET:-http://localhost:8081}"
DURATION="${DURATION:-15}"
CONCURRENCY="${CONCURRENCY:-50}"
OUT="${OUT:-reports/benchmarks/game_results.csv}"
python3 -m pip install -q requests || true
BACKEND_URL="$TARGET" DURATION="$DURATION" CONCURRENCY="$CONCURRENCY" OUT="$OUT" \
  python3 tests/benchmark/game_bench.py
