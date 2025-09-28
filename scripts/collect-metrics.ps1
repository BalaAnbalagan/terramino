\
    param([int]$IntervalSec=2,[int]$DurationSec=60,[string]$OutDir = $(Join-Path "results" ("run-" + (Get-Date -Format "yyyyMMdd-HHmm"))))
    $metrics = Join-Path $OutDir "metrics"
    New-Item -ItemType Directory -Force -Path $metrics | Out-Null
    $t1 = Join-Path $metrics ("docker-" + (Get-Date -Format "yyyyMMdd-HHmm") + ".csv")
    $t2 = Join-Path $metrics ("hyperv-" + (Get-Date -Format "yyyyMMdd-HHmm") + ".csv")
    $deadline = (Get-Date).AddSeconds($DurationSec)
    "name,cpu,mem" | Set-Content $t1
    "name,state,cpu_usage,memory_mb" | Set-Content $t2
    while ((Get-Date) -lt $deadline) {
      docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}}" | Select-String -Pattern "^D\\d+-(frontend|backend|redis)" | ForEach-Object { Add-Content $t1 $_.ToString().Trim() }
      Get-VM | Where-Object { $_.Name -match "^V\\d+$" } | ForEach-Object {
        "{0},{1},{2},{3}" -f $_.Name,$_.State,$_.CPUUsage,$_.MemoryAssigned/1MB | Add-Content $t2
      }
      Start-Sleep -Seconds $IntervalSec
    }
    Write-Host "[✓] Metrics captured to $metrics"
