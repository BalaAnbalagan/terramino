Param(
  [string]$OutDir = "dist"
)
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
vagrant package vm-native --output "$OutDir/terramino-vm-native.box"
try {
  vagrant package docker-native --output "$OutDir/terramino-docker-native.box"
} catch {
  Write-Warning "docker-native packaging may be provider-specific; ensure consumers have Docker installed."
}
Get-FileHash "$OutDir\*.box" -Algorithm SHA256 | ForEach-Object {
  "$($_.Hash)  $(Split-Path $_.Path -Leaf)"
} | Set-Content "$OutDir\boxes.sha256"
Write-Host "Boxes in $OutDir, checksums in $OutDir\boxes.sha256"
