#!/usr/bin/env bash
set -euo pipefail
NET="${NET:-terramino_default}"
OUT="${OUT:-reports/benchmarks/redis_docker_$(date +%Y%m%d%H%M%S).csv}"
mkdir -p "$(dirname "$OUT")"
docker run --rm --network "$NET" redis:7-alpine \
  redis-benchmark -h redis -p 6379 -n 100000 --csv > "$OUT"
echo "Wrote $OUT"
