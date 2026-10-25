[CmdletBinding()]
param(
  [ValidateSet('Debug', 'Release')]
  [string]$Configuration = 'Debug',
  [string]$DefinesFile = 'tool/supabase_defines.json',
  [switch]$RefreshDependencies
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

Push-Location $projectRoot
try {
  $flutterArguments = @(
    'build',
    'apk',
    "--$($Configuration.ToLowerInvariant())"
  )
  if (-not $RefreshDependencies) {
    $packageConfig = Join-Path $projectRoot '.dart_tool\package_config.json'
    if (-not (Test-Path -LiteralPath $packageConfig)) {
      throw 'Dependencies are not ready. Run flutter pub get or use -RefreshDependencies.'
    }
    $flutterArguments += '--no-pub'
  }

  $resolvedDefines = Join-Path $projectRoot $DefinesFile
  if (Test-Path -LiteralPath $resolvedDefines) {
    $flutterArguments += "--dart-define-from-file=$resolvedDefines"
  }

  & flutter @flutterArguments
  if ($LASTEXITCODE -ne 0) {
    throw "Flutter Android build failed with exit code $LASTEXITCODE."
  }

  $suffix = $Configuration.ToLowerInvariant()
  $apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-$suffix.apk"
  if (-not (Test-Path -LiteralPath $apkPath)) {
    throw "Flutter produced no $Configuration APK."
  }

  Write-Host "Android APK: $apkPath"
} finally {
  Pop-Location
}
