param(
    [string]$FlutterCommand = 'flutter',
    [string]$DartCommand = 'dart',
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root '.env.local'
if (-not (Test-Path -LiteralPath $envFile)) {
    $bytes = New-Object byte[] 32
    $random = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $random.GetBytes($bytes) } finally { $random.Dispose() }
    $secret = [BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant()
    [IO.File]::WriteAllText($envFile, "MYSOLD_LOCAL_DB_PASSWORD=$secret`n", (New-Object Text.UTF8Encoding $false))
}
Push-Location (Join-Path $root 'frontend')
try {
    if (-not $SkipBuild) {
        & $FlutterCommand build web --release --no-tree-shake-icons --no-web-resources-cdn --no-wasm-dry-run
        if ($LASTEXITCODE -ne 0) { throw 'Flutter Web build failed.' }
        & $DartCommand run tool/stamp_web_build.dart
        if ($LASTEXITCODE -ne 0) { throw 'PWA stamping failed.' }
    }
    if (-not (Test-Path -LiteralPath 'build/web/main.dart.js')) { throw 'Build the Web app first.' }
} finally { Pop-Location }
Push-Location $root
try {
    & docker compose --project-name mysold-local --env-file $envFile -f compose.local.yaml up -d --build --wait --wait-timeout 180
    if ($LASTEXITCODE -ne 0) { throw 'Local Compose startup failed.' }
    Write-Host 'MySold LOCAL ONLY: http://localhost:28086'
} finally { Pop-Location }
