[CmdletBinding()]
param(
  [string[]]$TestPath = @(),
  [switch]$SkipAnalyze
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$packageConfig = Join-Path $projectRoot '.dart_tool\package_config.json'
if (-not (Test-Path -LiteralPath $packageConfig)) {
  throw 'Dependencies are not ready. Run flutter pub get first.'
}

Push-Location $projectRoot
try {
  if (-not $SkipAnalyze) {
    & flutter analyze --no-pub
    if ($LASTEXITCODE -ne 0) {
      throw "Flutter analyzer failed with exit code $LASTEXITCODE."
    }
  }

  $testArguments = @('test', '--no-pub', '--reporter', 'compact')
  if ($TestPath.Count -gt 0) {
    $testArguments += $TestPath
  }
  & flutter @testArguments
  if ($LASTEXITCODE -ne 0) {
    throw "Flutter tests failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
