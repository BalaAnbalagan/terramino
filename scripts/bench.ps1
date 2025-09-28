param(
  [int]$Requests = 200,
  [int]$Concurrency = 10,
  [string]$Endpoint = "/info",
  [string]$Targets = "vm,docker",
  [string]$OutDir = $(Join-Path "results" ("run-" + (Get-Date -Format "yyyyMMdd-HHmm")))
)
$ErrorActionPreference = "Stop"
$CURL = (Get-Command curl.exe -ErrorAction Stop).Source
$CurlFmt = '%{http_code},%{time_connect},%{time_starttransfer},%{time_total}\n'
$CurlCommon = @('--silent','--output','NUL')

# derive target URLs
function Get-VMUrls {
  $count = [int]($env:VM_INSTANCE_COUNT ?? $env:VM_COUNT ?? "3")
  $ipBase = $env:VM_IP_BASE ?? "10.10.0."
  $ipStart = [int]($env:VM_IP_START ?? "10")
  $port = [int]($env:VM_PORT_FE ?? "8081")
  $urls = @()
  1..$count | ForEach-Object {
    $octet = $ipStart + $_ - 1
    $urls += "http://${ipBase}${octet}:$port"
  }
  $urls
}

function Get-DockerUrls {
  $count = [int]($env:DC_INSTANCE_COUNT ?? $env:DC_COUNT ?? "4")
  $base = [int]($env:DC_PORT_BASE ?? "9082")
  $urls = @()
  1..$count | ForEach-Object {
    $urls += "http://localhost:{0}" -f ($base + $_ - 1)
  }
  $urls
}

$allTargets = @()
if ($Targets -match "vm") { $allTargets += (Get-VMUrls) }
if ($Targets -match "docker") { $allTargets += (Get-DockerUrls) }

if (-not $allTargets) { Write-Error "No targets derived."; exit 2 }

# Prepare output dirs
$rawDir = Join-Path $OutDir "raw"
$null = New-Item -ItemType Directory -Force -Path $rawDir

# Warmup
foreach ($u in $allTargets) {
  Write-Host "[warmup] $u$Endpoint"
  1..10 | ForEach-Object { curl -s "$u$Endpoint" | Out-Null }
}

# CSV header
$header = "target,endpoint,ts,http_code,time_connect_s,time_ttfb_s,time_total_s"

# Timed runs with background jobs per target
$jobs = @()
foreach ($u in $allTargets) {
  $label = ($u -replace 'https?://','').Replace(':','-')
  $csv = Join-Path $rawDir "$label.csv"
  Set-Content -Path $csv -Value $header
  $jobs += Start-Job -Name $label -ScriptBlock {
    param($u,$ep,$n,$csv)
    for ($i=0; $i -lt $n; $i++) {
      $ts = [DateTimeOffset]::Now.ToString("o")
      $out = curl --write-out "%{{http_code}},%{{time_connect}},%{{time_starttransfer}},%{{time_total}}" --silent --output NUL "$($u)$($ep)"
      Add-Content -Path $csv -Value "$u,$ep,$ts,$out"
    }
  } -ArgumentList $u,$Endpoint,$Requests,$csv
}

Wait-Job -Job $jobs | Out-Null
$jobs | Receive-Job | Out-Null
$jobs | Remove-Job

# Summaries
$summary = @()
foreach ($u in $allTargets) {
  $label = ($u -replace 'https?://','').Replace(':','-')
  $csv = Join-Path $rawDir "$label.csv"
  $rows = Import-Csv $csv
  $count = $rows.Count
  $ok = ($rows | Where-Object { $_.http_code -like "2*" }).Count
  $sr = if ($count -gt 0) { [math]::Round(100.0*$ok/$count,2) } else { 0 }
  $totals = $rows | ForEach-Object { [double]$_.time_total_s * 1000.0 }
  $connect = $rows | ForEach-Object { [double]$_.time_connect_s * 1000.0 }
  $ttfb = $rows | ForEach-Object { [double]$_.time_ttfb_s * 1000.0 }
  function Pct($arr,$p) {
    if ($arr.Count -eq 0) { return 0 }
    $sorted = $arr | Sort-Object
    $idx = [int][math]::Ceiling(($p/100.0)*$sorted.Count)-1
    if ($idx -lt 0) { $idx = 0 }
    $sorted[$idx]
  }
  $avg = if ($totals.Count) { [math]::Round(($totals | Measure-Object -Average).Average,2) } else { 0 }
  $p50 = [math]::Round((Pct $totals 50),2)
  $p90 = [math]::Round((Pct $totals 90),2)
  $p99 = [math]::Round((Pct $totals 99),2)
  $avgConn = if ($connect.Count) { [math]::Round(($connect | Measure-Object -Average).Average,2) } else { 0 }
  $avgTtfb = if ($ttfb.Count) { [math]::Round(($ttfb | Measure-Object -Average).Average,2) } else { 0 }

  $summary += [pscustomobject]@{ target=$u; requests=$count; success_rate_pct=$sr; avg_ms=$avg; p50_ms=$p50; p90_ms=$p90; p99_ms=$p99; avg_connect_ms=$avgConn; avg_ttfb_ms=$avgTtfb }
}
$summaryCsv = Join-Path $OutDir "summary.csv"
$summary | Export-Csv -NoTypeInformation -Path $summaryCsv

# Markdown
$md = @("# Terramino bench summary", "", "| target | requests | success% | avg ms | p50 | p90 | p99 | conn ms | ttfb ms |", "|---|---:|---:|---:|---:|---:|---:|---:|---:|")
foreach ($row in $summary) {
  $md += "| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} |" -f $row.target,$row.requests,$row.success_rate_pct,$row.avg_ms,$row.p50_ms,$row.p90_ms,$row.p99_ms,$row.avg_connect_ms,$row.avg_ttfb_ms
}
$mdPath = Join-Path $OutDir "summary.md"
Set-Content -Path $mdPath -Value ($md -join "`n")

Write-Host "[✓] Results:"
Write-Host " - $summaryCsv"
Write-Host " - $mdPath"

# Exit nonzero if any target below 95%
$bad = $summary | Where-Object { $_.success_rate_pct -lt 95 }
if ($bad) { exit 3 } else { exit 0 }
