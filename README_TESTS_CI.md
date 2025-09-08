# Terramino — Functional Tests, Benchmarks, CI/CD & Packaging

## Quick start (Docker-Native on localhost)
```bash
make test-docker-native FRONTEND_URL=http://localhost:8080 BACKEND_URL=http://localhost:8081 PROM_URL=http://localhost:9090 GRAFANA_URL=http://localhost:3000
make bench-http-docker BACKEND_URL=http://localhost:8081
make bench-redis-docker
make charts
make export-docker-images
```

## Quick start (VM-Native on 192.168.56.50)
```bash
make test-vm-native FRONTEND_URL=http://192.168.56.50 BACKEND_URL=http://192.168.56.50:8081 PROM_URL=http://192.168.56.50:9090 GRAFANA_URL=http://192.168.56.50:3000
make bench-http-vm BACKEND_URL=http://192.168.56.50:8081
make bench-redis-vm
make package-vagrant   # produces .box files into dist/
```

Artifacts land under `reports/`:
- `reports/functional/*.xml` — JUnit
- `reports/benchmarks/*.csv` — bench data
- `reports/charts/*.png` — charts

`dist/` will contain exported Docker images and/or Vagrant .box files + checksums.

## CI
- `.github/workflows/ci.yml`: builds images, brings up a compose stack, runs functional tests + short benches, uploads artifacts.
- `.github/workflows/release.yml`: on tag `v*.*.*`, builds and **attaches Docker images** + checksums to a GitHub Release.
  - Optional job `package-vagrant-boxes` runs on **self-hosted** runner (requires VirtualBox + Vagrant) to attach `.box` files too.


## Windows quick commands (PowerShell)

### Functional tests
```powershell
python -m pip install requests
.\tests\functional\run.ps1 -FrontendUrl http://localhost:8080 -BackendUrl http://localhost:8081 -PromUrl http://localhost:9090 -GrafanaUrl http://localhost:3000
# VM variant
.\tests\functional\run.ps1 -FrontendUrl http://192.168.56.50 -BackendUrl http://192.168.56.50:8081 -PromUrl http://192.168.56.50:9090 -GrafanaUrl http://192.168.56.50:3000
```

### HTTP benchmark
```powershell
.\tests\benchmark\http_bench.ps1 -Concurrency 100 -DurationSec 15 -Url http://localhost:8081/api/health
```

### Redis benchmark (Docker stack)
```powershell
docker run --rm --network terramino_default redis:7-alpine `
  redis-benchmark -h redis -p 6379 -n 100000 --csv > .\reports\benchmarks\redis_docker_win.csv
```

### Redis benchmark (VM)
```powershell
vagrant ssh vm-native -c 'redis-benchmark -h 127.0.0.1 -p 6379 -n 100000 --csv' > .\reports\benchmarks\redis_vm_win.csv
```

### Charts
```powershell
python .\reports\charts.py
Start-Process .\reports\charts\http_rps.png
```

### Export Docker images (Windows-friendly)
```powershell
.\scripts\export-docker-images.ps1
```

### Package Vagrant boxes
```powershell
.\scripts\package-vagrant.ps1
```


## Game benchmark (/api/new-game)

### PowerShell
```powershell
# Docker-native
PowerShell -NoProfile -ExecutionPolicy Bypass -File .\tests\benchmark\game_bench.ps1 `
  -Target http://localhost:8081 -DurationSec 15 -Concurrency 50 -Out .\reports\benchmarks\game_results.csv

# VM-native
PowerShell -NoProfile -ExecutionPolicy Bypass -File .\tests\benchmark\game_bench.ps1 `
  -Target http://192.168.56.50:8081 -DurationSec 15 -Concurrency 50 -Out .\reports\benchmarks\game_vm.csv
```

### Bash
```bash
TARGET=http://localhost:8081 DURATION=15 CONCURRENCY=50 OUT=reports/benchmarks/game_results.csv \
  ./tests/benchmark/game_bench.sh
```

This records:
- RPS, mean, p50/p95/p99 latency, successes & errors
- CSV at `reports/benchmarks/game_*.csv`
- Charts at `reports/charts/game_rps.png` and `reports/charts/game_p95.png`


## Measure boot time (time-to-ready)

### PowerShell
```powershell
# Docker-Native
PowerShell -NoProfile -ExecutionPolicy Bypass -File .\scripts\measure-boot.ps1 -Stack docker -Rebuild `
  -FrontendUrl http://localhost:8080 -BackendUrl http://localhost:8081 -PromUrl http://localhost:9090 -GrafanaUrl http://localhost:3000

# VM-Native
PowerShell -NoProfile -ExecutionPolicy Bypass -File .\scripts\measure-boot.ps1 -Stack vm -VmName vm-native -Rebuild `
  -FrontendUrl http://192.168.56.50 -BackendUrl http://192.168.56.50:8081 -PromUrl http://192.168.56.50:9090 -GrafanaUrl http://192.168.56.50:3000
```

This writes `reports\boot\boot_times.csv` with columns:
`timestamp,stack,mode,t_total_ready_s,t_backend_s,t_frontend_s,t_prom_s,t_grafana_s,vm_systemd_total_s`

Render a boot chart:
```powershell
python .\reports\charts.py
Start-Process .\reports\charts\boot_ready_compare.png
```

### Bash
```bash
STACK=docker REBUILD=true ./scripts/measure-boot.sh
STACK=vm VM_NAME=vm-native REBUILD=true \
  FRONTEND_URL=http://192.168.56.50 BACKEND_URL=http://192.168.56.50:8081 PROM_URL=http://192.168.56.50:9090 GRAFANA_URL=http://192.168.56.50:3000 \
  ./scripts/measure-boot.sh
python3 reports/charts.py
```
