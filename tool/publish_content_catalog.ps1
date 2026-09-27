[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^\d{4}\.\d{2}\.\d{2}\.\d+$')]
  [string] $Version,
  [string] $SupabaseUrl = 'https://hjihhrcxkpzglgfmfuzs.supabase.co',
  [string] $InputDirectory = 'assets/content'
)

$ErrorActionPreference = 'Stop'

function Read-SecretKey {
  $value = $env:SUPABASE_SECRET_KEY
  if ([string]::IsNullOrWhiteSpace($value)) {
    $value = $env:SUPABASE_SERVICE_ROLE_KEY
  }
  if (-not [string]::IsNullOrWhiteSpace($value)) {
    return $value.Trim()
  }

  $secureValue = Read-Host 'Supabase secret/service-role key (не сохраняется)' -AsSecureString
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
  dart run tool/build_content_catalog.dart "--version=$Version" "--output=$InputDirectory"
  if ($LASTEXITCODE -ne 0) { throw 'Content catalog build failed.' }

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
