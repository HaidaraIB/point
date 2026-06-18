# Downloads Firebase JS SDK files used by FlutterFire web and patches internal imports to relative paths.
# Run after upgrading firebase_core / firebase_core_web (check supportedFirebaseJsSdkVersion in pub cache).

$ErrorActionPreference = 'Stop'
$version = '12.14.0'
$outDir = Join-Path $PSScriptRoot '..' 'web' 'firebasejs' $version | Resolve-Path -ErrorAction SilentlyContinue
if (-not $outDir) {
    $outDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'web' 'firebasejs' $version
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$files = @(
    'firebase-app.js',
    'firebase-auth.js',
    'firebase-firestore-pipelines.js',
    'firebase-storage.js'
)

foreach ($f in $files) {
    $url = "https://www.gstatic.com/firebasejs/$version/$f"
    $dest = Join-Path $outDir $f
    Write-Host "Downloading $url ..."
    curl.exe -s -o $dest $url
    $content = (Get-Content $dest -Raw) -replace "https://www.gstatic.com/firebasejs/$version/", './'
    Set-Content $dest $content -NoNewline
    Write-Host "  -> $dest ($((Get-Item $dest).Length) bytes)"
}

Write-Host "Done. Update the import map version in web/index.html if $version changed."
