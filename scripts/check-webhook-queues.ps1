# Run by Matt. Answers Phase 3 gate 2 - does the Job Tracker webhook expose
# an "unscored" queue, or only fit10/interested? - without the webhook URL
# ever reaching a model's context. It's a write credential for the tracker,
# not just an address (STATE.md, 2026-09-11), so it's treated like one:
# entered hidden, used once, never echoed. Only the queue NAMES print -
# never the URL, never row contents.

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

function ConvertFrom-SecureStringPlain {
  param([Parameter(Mandatory)][System.Security.SecureString]$Secure)
  return [System.Net.NetworkCredential]::new('', $Secure).Password
}

Write-Host ""
Write-Host "Checks what queues the Job Tracker webhook exposes via ?report=queue."
Write-Host "Only the queue names print below - never the URL, never row data."
Write-Host ""

$secureUrl = Read-Host -Prompt 'Job Tracker webhook URL (input hidden)' -AsSecureString
$urlPlain  = ConvertFrom-SecureStringPlain -Secure $secureUrl
$secureUrl = $null

$response = $null
try {
  try {
    $separator = if ($urlPlain.Contains('?')) { '&' } else { '?' }
    $response = Invoke-RestMethod -Method Get -Uri "$urlPlain${separator}report=queue"
  } catch {
    $detail = if ($_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
    Write-Host ""
    Write-Host "Request failed: $detail" -ForegroundColor Red
    exit 1
  }
}
finally {
  $urlPlain = $null
}

$queueNames = @($response.PSObject.Properties.Name)

Write-Host ""
Write-Host "Top-level queues returned:"
foreach ($name in $queueNames) {
  $count = $response.$name
  $count = if ($count -is [System.Array]) { $count.Count } else { '(not a list)' }
  Write-Host "  - $name : $count row(s)"
}
Write-Host ""
Write-Host "Report back just the list above (names and counts) - nothing else needed."
Write-Host ""

$response = $null

exit 0
