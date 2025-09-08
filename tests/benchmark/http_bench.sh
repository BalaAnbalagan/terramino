#!/usr/bin/env bash
set -euo pipefail
CONCURRENCY="${1:-50}"
DURATION="${2:-15}"
URL="${URL:-http://localhost:8081/api/health}"
OUT="${OUT:-reports/benchmarks/http_$(date +%Y%m%d%H%M%S).csv}"
mkdir -p "$(dirname "$OUT")"

if command -v hey >/dev/null 2>&1; then
  HEY=(hey)
elif command -v docker >/dev/null 2>&1; then
  HEY=(docker run --rm rakyll/hey)
else
  echo "Need 'hey' or 'docker' for the benchmark" >&2
  exit 1
fi

set +e
RAW="$("${HEY[@]}" -z "${DURATION}s" -c "${CONCURRENCY}" "$URL" 2>&1)"
RC=$?
set -e
echo "$RAW" > reports/benchmarks/http_raw.txt
if [ $RC -ne 0 ]; then
  echo "hey failed (rc=$RC). See reports/benchmarks/http_raw.txt" >&2
  exit 1
fi

# Parse Requests/sec and latency numbers; hey prints seconds values.
req_per_sec=$(echo "$RAW" | awk '/Requests\/sec:/{print $2}' | head -n1)
avg_s=$(echo "$RAW" | awk '/Average:/{print $2}' | head -n1)
p95_s=$(echo "$RAW" | awk '/95% in/{print $(NF-1)}' | head -n1)
p99_s=$(echo "$RAW" | awk '/99% in/{print $(NF-1)}' | head -n1)

to_ms() {
  local val="$1"
  if [ -z "$val" ]; then echo ""; return; fi
  # if like "12ms"
  if [[ "$val" =~ ^[0-9.]+ms$ ]]; then echo "${val%ms}"; return; fi
  # assume seconds -> ms
  awk -v v="$val" 'BEGIN{ printf "%.3f", v*1000 }'
}

avg_ms=$(to_ms "$avg_s")
p95_ms=$(to_ms "$p95_s")
p99_ms=$(to_ms "$p99_s")

# Approximate requests if missing
if [ -n "$req_per_sec" ]; then
  requests=$(awk -v r="$req_per_sec" -v d="$DURATION" 'BEGIN{ printf "%.0f", r*d }')
else
  requests=""
fi

echo "timestamp,url,concurrency,duration_s,requests,req_per_sec,avg_latency_ms,p95_ms,p99_ms" > "$OUT"
TS=$(date -u +%FT%TZ)
echo "${TS},${URL},${CONCURRENCY},${DURATION},${requests},${req_per_sec},${avg_ms},${p95_ms},${p99_ms}" >> "$OUT"
echo "Wrote $OUT"
