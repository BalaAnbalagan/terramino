Param(
  [string]$FrontendUrl = "http://localhost:8080",
  [string]$BackendUrl  = "http://localhost:8081",
  [string]$PromUrl     = "http://localhost:9090",
  [string]$GrafanaUrl  = "http://localhost:3000",
  [bool]$ExpectNode    = $true,
  [bool]$ExpectCadvisor= $false
)
$env:FRONTEND_URL   = $FrontendUrl
$env:BACKEND_URL    = $BackendUrl
$env:PROM_URL       = $PromUrl
$env:GRAFANA_URL    = $GrafanaUrl
$env:EXPECT_NODE    = if($ExpectNode){ "true" } else { "false" }
$env:EXPECT_CADVISOR= if($ExpectCadvisor){ "true" } else { "false" }
$env:OUT_JUNIT      = "reports/functional/results.xml"

python -m pip install --quiet requests || Write-Host "requests already present or pip not found"
python .\tests\functional\test_functional.py
exit $LASTEXITCODE
