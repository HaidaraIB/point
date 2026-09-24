# Deploy all Supabase Edge Functions + Firebase Firestore rules & indexes.
#
# Usage:
#   .\scripts\deploy-backend.ps1 --project-ref nbyhcxhdkxrathjaacvj --project-id point-agency-production
#
# Options:
#   --project-ref <ref>   Supabase project ref (required unless --only firebase)
#   --project-id <id>     Firebase project id (required unless --only supabase)
#   --only <target>       all | supabase | firebase  (default: all)
#   --use-api             Bundle Supabase functions via API (no local Docker)
#   -h, --help            Show help

$ErrorActionPreference = 'Stop'

function Show-Usage {
    @"
Deploy all Supabase Edge Functions and Firebase Firestore rules/indexes.

Usage:
  .\scripts\deploy-backend.ps1 --project-ref <ref> --project-id <id>
  .\scripts\deploy-backend.ps1 --only supabase --project-ref <ref>
  .\scripts\deploy-backend.ps1 --only firebase --project-id <id>

Options:
  --project-ref <ref>   Supabase project ref
  --project-id <id>     Firebase project id
  --only <target>       all | supabase | firebase  (default: all)
  --use-api             Pass --use-api to supabase functions deploy (no Docker)
  -h, --help            Show this help

Examples:
  .\scripts\deploy-backend.ps1 --project-ref nbyhcxhdkxrathjaacvj --project-id point-agency-production
  .\scripts\deploy-backend.ps1 --only firebase --project-id point-f33cb
"@ | Write-Host
}

$ProjectRef = $null
$ProjectId = $null
$Only = 'all'
$UseApi = $false

$i = 0
while ($i -lt $args.Count) {
    switch ($args[$i]) {
        { $_ -in @('-h', '--help') } {
            Show-Usage
            exit 0
        }
        '--project-ref' {
            $i++
            if ($i -ge $args.Count) { throw '--project-ref requires a value' }
            $ProjectRef = [string]$args[$i]
        }
        '--project-id' {
            $i++
            if ($i -ge $args.Count) { throw '--project-id requires a value' }
            $ProjectId = [string]$args[$i]
        }
        '--only' {
            $i++
            if ($i -ge $args.Count) { throw '--only requires a value (all|supabase|firebase)' }
            $Only = ([string]$args[$i]).ToLowerInvariant()
            if ($Only -notin @('all', 'supabase', 'firebase')) {
                throw "Invalid --only value: $Only (expected all|supabase|firebase)"
            }
        }
        '--use-api' {
            $UseApi = $true
        }
        default {
            throw "Unknown argument: $($args[$i]). Use --help for usage."
        }
    }
    $i++
}

$DeploySupabase = $Only -in @('all', 'supabase')
$DeployFirebase = $Only -in @('all', 'firebase')

if ($DeploySupabase -and [string]::IsNullOrWhiteSpace($ProjectRef)) {
    Show-Usage
    throw '--project-ref is required when deploying Supabase functions'
}
if ($DeployFirebase -and [string]::IsNullOrWhiteSpace($ProjectId)) {
    Show-Usage
    throw '--project-id is required when deploying Firebase rules/indexes'
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $RepoRoot

function Assert-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "'$Name' CLI not found on PATH. Install it and retry."
    }
}

Write-Host ""
Write-Host "Repo: $RepoRoot"
Write-Host "Target: $Only"
if ($DeploySupabase) { Write-Host "Supabase project-ref: $ProjectRef" }
if ($DeployFirebase) { Write-Host "Firebase project-id:  $ProjectId" }
Write-Host ""

if ($DeploySupabase) {
    Assert-Command 'supabase'

    $functionsDir = Join-Path (Join-Path $RepoRoot 'supabase') 'functions'
    $functionNames = Get-ChildItem -Path $functionsDir -Directory |
        Where-Object { $_.Name -ne '_shared' -and (Test-Path (Join-Path $_.FullName 'index.ts')) } |
        Select-Object -ExpandProperty Name |
        Sort-Object

    if ($functionNames.Count -eq 0) {
        throw "No Edge Functions found under supabase/functions"
    }

    Write-Host "=== Supabase Edge Functions ($($functionNames.Count)) ==="
    $functionNames | ForEach-Object { Write-Host "  - $_" }
    Write-Host ""

    $supabaseArgs = @(
        'functions', 'deploy',
        '--project-ref', $ProjectRef,
        '--yes'
    )
    if ($UseApi) {
        $supabaseArgs += '--use-api'
    }

    Write-Host "> supabase $($supabaseArgs -join ' ')"
    & supabase @supabaseArgs
    if ($LASTEXITCODE -ne 0) {
        throw "supabase functions deploy failed (exit $LASTEXITCODE)"
    }
    Write-Host "Supabase functions deploy OK."
    Write-Host ""
}

if ($DeployFirebase) {
    Assert-Command 'firebase'

    $rulesPath = Join-Path $RepoRoot 'firestore.rules'
    $indexesPath = Join-Path $RepoRoot 'firestore.indexes.json'
    if (-not (Test-Path $rulesPath)) { throw "Missing $rulesPath" }
    if (-not (Test-Path $indexesPath)) { throw "Missing $indexesPath" }

    Write-Host "=== Firebase Firestore rules + indexes ==="
    Write-Host "  rules:   firestore.rules"
    Write-Host "  indexes: firestore.indexes.json"
    Write-Host ""

    $firebaseArgs = @(
        'deploy',
        '--only', 'firestore:rules,firestore:indexes',
        '--project', $ProjectId,
        '--non-interactive'
    )

    Write-Host "> firebase $($firebaseArgs -join ' ')"
    & firebase @firebaseArgs
    if ($LASTEXITCODE -ne 0) {
        throw "firebase deploy failed (exit $LASTEXITCODE)"
    }
    Write-Host "Firebase rules/indexes deploy OK."
    Write-Host ""
}

Write-Host "Done."
