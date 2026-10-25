[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^\d{4}\.\d{2}\.\d{2}\.\d+$')]
  [string] $Version,
  [string] $SupabaseUrl = 'https://hjihhrcxkpzglgfmfuzs.supabase.co',
  [string] $InputDirectory = 'assets/content',
  [switch] $UseExistingPackage,
  [switch] $InteractiveChild
)

$ErrorActionPreference = 'Stop'

$hasEnvironmentKey =
  -not [string]::IsNullOrWhiteSpace($env:SUPABASE_SECRET_KEY) -or
  -not [string]::IsNullOrWhiteSpace($env:SUPABASE_SERVICE_ROLE_KEY)

if (-not $hasEnvironmentKey -and -not $InteractiveChild) {
  $powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
  $arguments = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $PSCommandPath,
    '-Version', $Version,
    '-SupabaseUrl', $SupabaseUrl,
    '-InputDirectory', $InputDirectory,
    '-InteractiveChild'
  )
  if ($UseExistingPackage) {
    $arguments += '-UseExistingPackage'
  }
  $process = Start-Process -FilePath $powershell -ArgumentList $arguments `
    -WorkingDirectory (Get-Location).Path -WindowStyle Normal -Wait -PassThru
  if ($process.ExitCode -ne 0) {
    throw "Visible publication window failed with exit code $($process.ExitCode)."
  }
  return
}

function Read-SecretKey {
  $value = $env:SUPABASE_SECRET_KEY
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = $env:SUPABASE_SERVICE_ROLE_KEY
  }
  if (-not [string]::IsNullOrWhiteSpace($value)) {
    return $value.Trim()
  }

  $secureValue = Read-Host 'Supabase secret/service-role key (not saved)' -AsSecureString
  $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureValue)
  try {
    $value = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
  }
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw 'Supabase secret/service-role key is required.'
  }
  return $value.Trim()
}

$previousUrl = $env:SUPABASE_URL
$previousSecretKey = $env:SUPABASE_SECRET_KEY
$env:SUPABASE_URL = $SupabaseUrl.TrimEnd('/')
$env:SUPABASE_SECRET_KEY = Read-SecretKey

try {
  if ($UseExistingPackage) {
    $manifestPath = Join-Path $InputDirectory 'manifest.json'
    $catalogPath = Join-Path $InputDirectory 'catalog.json.gz'
    if (
      -not (Test-Path -LiteralPath $manifestPath) -or
      -not (Test-Path -LiteralPath $catalogPath)
    ) {
      throw 'Existing content package is incomplete.'
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.content_version -ne $Version) {
      throw "Existing package version '$($manifest.content_version)' does not match '$Version'."
    }
  } else {
    dart run tool/build_content_catalog.dart "--version=$Version" "--output=$InputDirectory"
    if ($LASTEXITCODE -ne 0) { throw 'Content catalog build failed.' }
  }

  dart run tool/publish_content_catalog.dart "--input=$InputDirectory"
  if ($LASTEXITCODE -ne 0) { throw 'Content catalog publication failed.' }
} finally {
  if ($null -eq $previousUrl) {
    Remove-Item Env:SUPABASE_URL -ErrorAction SilentlyContinue
  } else {
    $env:SUPABASE_URL = $previousUrl
  }
  if ($null -eq $previousSecretKey) {
    Remove-Item Env:SUPABASE_SECRET_KEY -ErrorAction SilentlyContinue
  } else {
    $env:SUPABASE_SECRET_KEY = $previousSecretKey
  }
}
