Param(
  [int]$Concurrency = 50,
  [int]$DurationSec = 15,
  [string]$Url = "http://localhost:8081/api/health",
  [string]$Out = "reports/benchmarks/http_{0}.csv" -f (Get-Date -UFormat "%Y%m%d%H%M%S")
)
New-Item -ItemType Directory -Force -Path (Split-Path $Out) | Out-Null

# Prefer local 'hey', else use dockerized image
$heyCmd = "hey"
if (-not (Get-Command $heyCmd -ErrorAction SilentlyContinue)) {
  if (Get-Command docker -ErrorAction SilentlyContinue) {
    $heyCmd = "docker run --rm rakyll/hey"
  } else {
    Write-Error "Neither 'hey' nor 'docker' is available."
    exit 1
  }
}

# Run hey; capture stdout+stderr
$rawFile = "reports/benchmarks/http_raw.txt"
New-Item -ItemType Directory -Force -Path (Split-Path $rawFile) | Out-Null
$cmd = "$heyCmd -z ${DurationSec}s -c $Concurrency $Url"
Write-Host "Running: $cmd"
$raw = & cmd /c $cmd 2>&1
$raw | Out-File -Encoding utf8 $rawFile

# Helper: extract first group value if regex matches, else ""
function Extract-First($text, $pattern) {
  $m = [regex]::Match($text, $pattern, 'IgnoreCase, Multiline')
  if ($m.Success -and $m.Groups.Count -ge 2) { return $m.Groups[1].Value.Trim() } else { return "" }
}

# Parse values (hey's "Requests/sec", "Average: <secs>", percentile lines)
$reqPerSec = Extract-First $raw 'Requests/sec:\s+([0-9.]+)'
$avgRaw    = Extract-First $raw 'Average:\s+([0-9.]+)\s*(?:secs|s|ms)?'
$p95Raw    = Extract-First $raw '95% in\s+([0-9.]+)\s*(?:secs|s|ms)?'
$p99Raw    = Extract-First $raw '99% in\s+([0-9.]+)\s*(?:secs|s|ms)?'

# Units: hey prints seconds by default (e.g., 0.0051 secs). Assume seconds when unit missing.
function ToMs($val) {
  if ([string]::IsNullOrWhiteSpace($val)) { return "" }
  # If the value looks like "12ms", strip unit; if seconds, multiply.
  if ($val -match '^\s*([0-9.]+)\s*ms\s*$') { return [double]$matches[1] }
  else { return [double]$val * 1000.0 }
}

$avgMs = if ($avgRaw) { ToMs $avgRaw } else { "" }
$p95Ms = if ($p95Raw) { ToMs $p95Raw } else { "" }
$p99Ms = if ($p99Raw) { ToMs $p99Raw } else { "" }

# Total requests is not printed by some hey builds; approximate from RPS*duration if missing.
$totalReq = ""
if ($reqPerSec) {
  try { $totalReq = [int]([double]$reqPerSec * $DurationSec) } catch { $totalReq = "" }
}

"timestamp,url,concurrency,duration_s,requests,req_per_sec,avg_latency_ms,p95_ms,p99_ms" | Out-File -Encoding utf8 $Out
$ts = (Get-Date).ToUniversalTime().ToString("s") + "Z"
"$ts,$Url,$Concurrency,$DurationSec,$totalReq,$reqPerSec,$avgMs,$p95Ms,$p99Ms" | Out-File -Append -Encoding utf8 $Out

Write-Host "Wrote $Out"
