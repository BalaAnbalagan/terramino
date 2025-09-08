#!/usr/bin/env bash
set -euo pipefail
OUT="${OUT:-reports/benchmarks/redis_vm_$(date +%Y%m%d%H%M%S).csv}"
mkdir -p "$(dirname "$OUT")"
vagrant ssh vm-native -c 'redis-benchmark -h 127.0.0.1 -p 6379 -n 100000 --csv' > "$OUT"
echo "Wrote $OUT"
