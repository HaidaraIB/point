# Build point-storage-migration.zip for upload to your VPS (excludes secrets and node_modules).
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$zipName = "point-storage-migration.zip"
if (Test-Path $zipName) { Remove-Item $zipName -Force }

$files = @(
  "migrate.mjs",
  "package.json",
  ".env.example",
  "README.md",
  "run.sh",
  ".gitignore"
)

Compress-Archive -Path ($files + "lib") -DestinationPath $zipName -Force
Write-Host "Created $zipName"
Write-Host "Next: upload zip + firebase-sa.json + .env to VPS, then npm install && ./run.sh ..."
