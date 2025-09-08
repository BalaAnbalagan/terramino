Param(
  [ValidateSet("docker","vm")] [string]$Stack = "docker",
  [string]$VmName = "vm-native",
  [string]$FrontendUrl = "http://localhost:8080",
  [string]$BackendUrl  = "http://localhost:8081",
  [string]$PromUrl     = "http://localhost:9090",
  [string]$GrafanaUrl  = "http://localhost:3000",
  [switch]$Rebuild,
  [int]$TimeoutSec = 900,
  [string]$OutCsv = ".\reports\boot\boot_times.csv"
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path (Split-Path $OutCsv) | Out-Null

function NowMs { ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) }

function Wait-Http200([string]$url, [int]$timeoutSec) {
  $deadline = (Get-Date).AddSeconds($timeoutSec)
  while ((Get-Date) -lt $deadline) {
    try {
      $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5
      if ($r.StatusCode -eq 200) { return $true }
    } catch { Start-Sleep -Milliseconds 300 }
  }
  return $false
}

function Docker-Deploy {
  if ($Rebuild) {
    try { docker stack rm terramino | Out-Null } catch {}
    Start-Sleep -Seconds 3
  }
  try { docker network create --driver overlay --attachable terramino_default | Out-Null } catch {}
  docker stack deploy -c .\docker\docker-stack.yml terramino | Out-Null
}

function Vm-Up {
  if ($Rebuild) {
    vagrant destroy -f $VmName | Out-Null
  }
  vagrant up $VmName | Out-Null
}

function Vm-Get-SystemdAnalyze {
  try {
    $out = vagrant ssh $VmName -c 'systemd-analyze --no-pager' 2>$null
    $m = [regex]::Match($out,'Startup finished in\s+([0-9.]+)s.*\+\s+([0-9.]+)s.*=\s+([0-9.]+)s')
    if ($m.Success) {
      return @{ kernel_s = [double]$m.Groups[1].Value; userspace_s = [double]$m.Groups[2].Value; total_s = [double]$m.Groups[3].Value }
    }
  } catch {}
  return @{}
}

# ----- start measurement -----
$ts = (Get-Date).ToUniversalTime().ToString("s") + "Z"
$t0 = NowMs

if ($Stack -eq "docker") { Docker-Deploy } else { Vm-Up }

$backendReadyMs  = $null
$frontendReadyMs = $null
$promReadyMs     = $null
$grafReadyMs     = $null

$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline) {
  if (-not $backendReadyMs  -and (Wait-Http200 "$BackendUrl/api/health" 1)) { $backendReadyMs  = NowMs }
  if (-not $frontendReadyMs -and (Wait-Http200 "$FrontendUrl/" 1))         { $frontendReadyMs = NowMs }
  if (-not $promReadyMs     -and (Wait-Http200 "$PromUrl/-/ready" 1))      { $promReadyMs     = NowMs }
  if (-not $grafReadyMs     -and (Wait-Http200 "$GrafanaUrl/login" 1))     { $grafReadyMs     = NowMs }
  if ($backendReadyMs -and $frontendReadyMs -and $promReadyMs -and $grafReadyMs) { break }
  Start-Sleep -Milliseconds 250
}

function DeltaSec($ms, $t0ref) {
  if ($ms) { [math]::Round(($ms - $t0ref)/1000.0, 3) } else { "" }
}

# time-to-ready = latest milestone
$t_ready = ""
$times = @()
foreach ($x in @($backendReadyMs,$frontendReadyMs,$promReadyMs,$grafReadyMs)) { if ($x) { $times += $x } }
if ($times.Count -gt 0) {
  $maxMs = ($times | Measure-Object -Maximum).Maximum
  $t_ready = [math]::Round(($maxMs - $t0)/1000.0, 3)
}

$vmBoot = ""
if ($Stack -eq "vm") {
  $info = Vm-Get-SystemdAnalyze
  if ($info.ContainsKey("total_s")) { $vmBoot = [math]::Round($info.total_s,3) }
}

$mode = if ($Rebuild) { "rebuild" } else { "start" }
$headers = "timestamp,stack,mode,t_total_ready_s,t_backend_s,t_frontend_s,t_prom_s,t_grafana_s,vm_systemd_total_s"
if (-not (Test-Path $OutCsv)) { $headers | Out-File -Encoding utf8 $OutCsv }

$line = "{0},{1},{2},{3},{4},{5},{6},{7},{8}" -f @(
  $ts, $Stack, $mode,
  $t_ready,
  (DeltaSec $backendReadyMs  $t0),
  (DeltaSec $frontendReadyMs $t0),
  (DeltaSec $promReadyMs     $t0),
  (DeltaSec $grafReadyMs     $t0),
  $vmBoot
)
$line | Out-File -Append -Encoding utf8 $OutCsv
Write-Host "Wrote $OutCsv"
