#!/usr/bin/env bash
set -euo pipefail

REQ=${1:-200}
CONC=${2:-10}
EP=${3:-/info}
OUTDIR=${4:-results/run-$(date +%Y%m%d-%H%M)}

vm_count=${VM_INSTANCE_COUNT:-${VM_COUNT:-3}}
vm_ip_base=${VM_IP_BASE:-10.10.0.}
vm_ip_start=${VM_IP_START:-10}
vm_port=${VM_PORT_FE:-8081}

dc_count=${DC_INSTANCE_COUNT:-${DC_COUNT:-4}}
dc_port_base=${DC_PORT_BASE:-9082}

targets=()

# VM targets
for i in $(seq 1 $vm_count); do
  o=$((vm_ip_start + i - 1))
  targets+=("http://${vm_ip_base}${o}:${vm_port}")
done

# Docker targets
for i in $(seq 1 $dc_count); do
  p=$((dc_port_base + i - 1))
  targets+=("http://localhost:${p}")
done

raw="${OUTDIR}/raw"
mkdir -p "$raw"

# warmup
for t in "${targets[@]}"; do
  for i in $(seq 1 10); do curl -s "${t}${EP}" >/dev/null || true; done
done

header="target,endpoint,ts,http_code,time_connect_s,time_ttfb_s,time_total_s"

for t in "${targets[@]}"; do
  label="${t#http://}"; label="${label//:/-}"
  csv="${raw}/${label}.csv"
  echo "$header" > "$csv"
  seq 1 "$REQ" | xargs -P "$CONC" -I{} sh -c '
    ts=$(date -Iseconds)
    out=$(curl --write-out "%{http_code},%{time_connect},%{time_starttransfer},%{time_total}" --silent --output /dev/null "'"${t}${EP}"'")
    echo "'"${t}"'","'"${EP}"'","$ts","$out"
  ' >> "$csv"
done

# simple summary (avg only)
summary="${OUTDIR}/summary.csv"
echo "target,requests,success_rate_pct,avg_ms" > "$summary"
for t in "${targets[@]}"; do
  label="${t#http://}"; label="${label//:/-}"
  csv="${raw}/${label}.csv"
  cnt=$(($(wc -l < "$csv") - 1))
  ok=$(awk -F, 'NR>1 && $4 ~ /^2/ {c++} END{print c+0}' "$csv")
  sr=$(awk -v ok="$ok" -v cnt="$cnt" 'BEGIN{ if(cnt>0) printf "%.2f", (100.0*ok/cnt); else print "0.00"}')
  avg=$(awk -F, 'NR>1 {sum+=$7;n++} END{ if(n>0) printf "%.2f", (1000.0*sum/n); else print "0.00"}' "$csv")
  echo "$t,$cnt,$sr,$avg" >> "$summary"
done

echo "[✓] Wrote $summary"
