#!/usr/bin/env bash
set -euo pipefail

STACK="${STACK:-docker}"   # docker|vm
VM_NAME="${VM_NAME:-vm-native}"
FRONTEND_URL="${FRONTEND_URL:-http://localhost:8080}"
BACKEND_URL="${BACKEND_URL:-http://localhost:8081}"
PROM_URL="${PROM_URL:-http://localhost:9090}"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
REBUILD="${REBUILD:-false}"
TIMEOUT_SEC="${TIMEOUT_SEC:-900}"
OUT_CSV="${OUT_CSV:-reports/boot/boot_times.csv}"

mkdir -p "$(dirname "$OUT_CSV")"

now_ms() { date +%s%3N; }
wait_http_200() {
  local url="$1" timeout="$2"
  local end=$(( $(date +%s) + timeout ))
  while [ "$(date +%s)" -lt "$end" ]; do
    if curl -fsS "$url" >/dev/null 2>&1; then return 0; fi
    sleep 0.25
  done
  return 1
}

docker_deploy() {
  if [ "$REBUILD" = "true" ]; then
    docker stack rm terramino >/dev/null 2>&1 || true
    sleep 3
  fi
  docker network create --driver overlay --attachable terramino_default >/dev/null 2>&1 || true
  docker stack deploy -c ./docker/docker-stack.yml terramino >/dev/null
}

vm_up() {
  if [ "$REBUILD" = "true" ]; then
    vagrant destroy -f "$VM_NAME" >/dev/null 2>&1 || true
  fi
  vagrant up "$VM_NAME" >/dev/null
}

vm_systemd_analyze() {
  vagrant ssh "$VM_NAME" -c 'systemd-analyze --no-pager' 2>/dev/null | awk '
    /Startup finished in/ {
      # Expect: Startup finished in 3.172s (kernel) + 8.574s (userspace) = 11.747s
      match($0, /in[[:space:]]*([0-9.]+)s.*\+[[:space:]]*([0-9.]+)s.*=[[:space:]]*([0-9.]+)s/, a);
      if (a[3] != "") print a[3];
    }'
}

t0="$(now_ms)"
ts="$(date -u +%FT%TZ)"

if [ "$STACK" = "docker" ]; then
  docker_deploy
else
  vm_up
fi

backend_ms= frontend_ms= prom_ms= graf_ms=

deadline=$(( $(date +%s) + TIMEOUT_SEC ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  if [ -z "${backend_ms:-}" ]; then if wait_http_200 "${BACKEND_URL%/}/api/health" 1; then backend_ms="$(now_ms)"; fi; fi
  if [ -z "${frontend_ms:-}" ]; then if wait_http_200 "${FRONTEND_URL%/}/" 1; then frontend_ms="$(now_ms)"; fi; fi
  if [ -z "${prom_ms:-}" ]; then if wait_http_200 "${PROM_URL%/}/-/ready" 1; then prom_ms="$(now_ms)"; fi; fi
  if [ -z "${graf_ms:-}" ]; then if wait_http_200 "${GRAFANA_URL%/}/login" 1; then graf_ms="$(now_ms)"; fi; fi
  if [ -n "${backend_ms:-}" ] && [ -n "${frontend_ms:-}" ] && [ -n "${prom_ms:-}" ] && [ -n "${graf_ms:-}" ]; then break; fi
  sleep 0.25
done

delta_sec() {
  local ms="$1"
  if [ -z "$ms" ]; then echo ""; else awk -v a="$ms" -v b="$t0" 'BEGIN{ printf "%.3f", (a-b)/1000.0 }'; fi
}

t_ready=""
max_ms=""
for m in "$backend_ms" "$frontend_ms" "$prom_ms" "$graf_ms"; do
  if [ -n "$m" ]; then
    if [ -z "$max_ms" ] || [ "$m" -gt "$max_ms" ]; then max_ms="$m"; fi
  fi
done
if [ -n "$max_ms" ]; then t_ready=$(awk -v a="$max_ms" -v b="$t0" 'BEGIN{ printf "%.3f", (a-b)/1000.0 }'); fi

vm_total=""
if [ "$STACK" = "vm" ]; then
  vm_total="$(vm_systemd_analyze)"
fi

headers="timestamp,stack,mode,t_total_ready_s,t_backend_s,t_frontend_s,t_prom_s,t_grafana_s,vm_systemd_total_s"
if [ ! -f "$OUT_CSV" ]; then
  echo "$headers" > "$OUT_CSV"
fi

printf "%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
  "$ts" "$STACK" "$([ "$REBUILD" = "true" ] && echo rebuild || echo start)" \
  "$t_ready" "$(delta_sec "$backend_ms")" "$(delta_sec "$frontend_ms")" "$(delta_sec "$prom_ms")" "$(delta_sec "$graf_ms")" \
  "$vm_total" >> "$OUT_CSV"

echo "Wrote $OUT_CSV"
