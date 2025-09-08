Param(
  [string]$Target = "http://localhost:8081",
  [int]$DurationSec = 15,
  [int]$Concurrency = 50,
  [string]$Out = "reports/benchmarks/game_results.csv"
)
python -m pip install --quiet requests | Out-Null
$env:BACKEND_URL = $Target
$env:DURATION = "$DurationSec"
$env:CONCURRENCY = "$Concurrency"
$env:OUT = $Out
python .\tests\benchmark\game_bench.py
