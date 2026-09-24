[CmdletBinding()]
param(
  [ValidateSet('Debug', 'Release')]
  [string]$Configuration = 'Debug',
  [string]$DefinesFile = 'tool/supabase_defines.json'
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$buildRoot = Join-Path $projectRoot 'build\windows\x64'
$bundleName = "Worttrieb-Windows-$Configuration"
$distRoot = Join-Path $projectRoot 'dist'
$bundlePath = Join-Path $distRoot $bundleName
$archivePath = Join-Path $distRoot "$bundleName.zip"

function Assert-ChildPath {
  param(
    [Parameter(Mandatory)] [string]$Parent,
    [Parameter(Mandatory)] [string]$Child
  )

  $parentPath = [IO.Path]::GetFullPath($Parent).TrimEnd(
    [IO.Path]::DirectorySeparatorChar
  )
  $childPath = [IO.Path]::GetFullPath($Child)
  if (-not $childPath.StartsWith(
      $parentPath + [IO.Path]::DirectorySeparatorChar,
      [StringComparison]::OrdinalIgnoreCase
    )) {
    throw "Unsafe output path: $childPath"
  }
}

Push-Location $projectRoot
try {
  $flutterArguments = @(
    'build',
    'windows',
    "--$($Configuration.ToLowerInvariant())"
  )
  $resolvedDefines = Join-Path $projectRoot $DefinesFile
  if (Test-Path -LiteralPath $resolvedDefines) {
    $flutterArguments += "--dart-define-from-file=$resolvedDefines"
  }

  & flutter @flutterArguments
  if ($LASTEXITCODE -ne 0) {
    throw "Flutter Windows build failed with exit code $LASTEXITCODE."
  }

  $bundleCandidates = Get-ChildItem -LiteralPath $buildRoot -Directory -Recurse |
    Where-Object {
      (Test-Path -LiteralPath (Join-Path $_.FullName 'deutsch_review.exe')) -and
      (Test-Path -LiteralPath (Join-Path $_.FullName 'flutter_windows.dll')) -and
      (Test-Path -LiteralPath (Join-Path $_.FullName 'data\flutter_assets'))
    } |
    Sort-Object {
      (Get-Item -LiteralPath (Join-Path $_.FullName 'deutsch_review.exe')).LastWriteTimeUtc
    } -Descending

  $sourceBundle = $bundleCandidates | Select-Object -First 1
  if ($null -eq $sourceBundle) {
    throw 'Flutter produced no complete Windows bundle.'
  }

  New-Item -ItemType Directory -Path $distRoot -Force | Out-Null
  Assert-ChildPath -Parent $projectRoot -Child $bundlePath
  Assert-ChildPath -Parent $projectRoot -Child $archivePath

  if (Test-Path -LiteralPath $bundlePath) {
    Remove-Item -LiteralPath $bundlePath -Recurse -Force
  }
  if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
  }

  New-Item -ItemType Directory -Path $bundlePath | Out-Null
  Get-ChildItem -LiteralPath $sourceBundle.FullName -Force |
    Copy-Item -Destination $bundlePath -Recurse -Force
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'windows_package_readme.txt') `
    -Destination (Join-Path $bundlePath 'README.txt')

  $requiredFiles = @(
    'deutsch_review.exe',
    'flutter_windows.dll',
    'sqlite3.dll',
    'data\icudtl.dat'
  )
  foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $bundlePath $relativePath))) {
      throw "Windows bundle is incomplete: $relativePath is missing."
    }
  }
  if (-not (Test-Path -LiteralPath (Join-Path $bundlePath 'data\flutter_assets'))) {
    throw 'Windows bundle is incomplete: Flutter assets are missing.'
  }

  Compress-Archive -LiteralPath $bundlePath -DestinationPath $archivePath

  Write-Host "Complete Windows bundle: $bundlePath"
  Write-Host "Archive: $archivePath"
} finally {
  Pop-Location
}
