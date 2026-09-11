# Run by Matt, whenever the $5/week ceiling needs checking. Prompts for the
# CAPPED key only - never the management key, which this script has no use
# for and should never be asked for. GET /api/v1/key reports on whichever
# key authenticates the call, so the capped key is all it needs.

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

function ConvertFrom-SecureStringPlain {
  param([Parameter(Mandatory)][System.Security.SecureString]$Secure)
  return [System.Net.NetworkCredential]::new('', $Secure).Password
}

Write-Host ""
Write-Host "Checks the OpenRouter spend ceiling on the CAPPED key (openclaw-automation)."
Write-Host "Not the management key - this script never needs that one."
Write-Host ""

$secureCapKey = Read-Host -Prompt 'OpenRouter capped API key (input hidden)' -AsSecureString
$capKeyPlain  = ConvertFrom-SecureStringPlain -Secure $secureCapKey
$secureCapKey = $null

$response = $null
try {
  try {
    $response = Invoke-RestMethod -Method Get -Uri 'https://openrouter.ai/api/v1/key' `
      -Headers @{ Authorization = "Bearer $capKeyPlain" }
  } catch {
    $detail = if ($_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
    Write-Host ""
    Write-Host "Lookup failed: $detail" -ForegroundColor Red
    exit 1
  }
}
finally {
  $capKeyPlain = $null
}

$limit          = $response.data.limit
$limitRemaining = $response.data.limit_remaining
$limitReset     = $response.data.limit_reset
$usageWeekly    = if ($null -ne $response.data.usage_weekly) { $response.data.usage_weekly } else { $response.data.usage }

Write-Host ""
Write-Host "limit:           $limit"
Write-Host "limit_remaining: $limitRemaining"
Write-Host "limit_reset:     $limitReset"
Write-Host "usage_weekly:    $usageWeekly"
Write-Host ""

$response = $null

exit 0
