Param(
  [string]$OutDir = "dist"
)
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
docker save -o "$OutDir\terramino-backend_local.tar" terramino-backend:local
docker save -o "$OutDir\terramino-frontend_local.tar" terramino-frontend:local
Get-FileHash "$OutDir\*" -Algorithm SHA256 | ForEach-Object {
  "$($_.Hash)  $(Split-Path $_.Path -Leaf)"
} | Set-Content "$OutDir\checksums.sha256"
Write-Host "Exported images to $OutDir"
