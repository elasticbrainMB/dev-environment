# Run by Matt. Answers Phase 3 gate 2 - does the Job Tracker webhook expose
# an "unscored" queue, or only fit10/interested? - without the webhook URL
# ever reaching a model's context. It's a write credential for the tracker,
# not just an address (STATE.md, 2026-09-11), so it's treated like one:
# entered hidden, used once, never echoed. Only structure prints - property
# names, array counts, and plain scalar values (e.g. a status code) - never
# row content.
#
# v2, 2026-09-12: the first version only looked one level deep and reported
# "(not a list)" for anything that wasn't a top-level array - which is
# exactly what a wrapped shape like {status, queue: {fit10:[...], ...}}
# looks like from one level up. This version reports one extra level of
# structure so a wrapped or nested response is actually legible.

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

function Show-Shape {
  param($Value, [string]$Name, [int]$IndentLevel)
  $indent = '  ' * ($IndentLevel + 1)
  if ($Value -is [System.Array]) {
    Write-Host "$indent- $Name : array, $($Value.Count) row(s)"
  }
  elseif ($Value -is [System.Management.Automation.PSCustomObject]) {
    $subNames = @($Value.PSObject.Properties.Name)
    Write-Host "$indent- $Name : object with keys: $($subNames -join ', ')"
    if ($IndentLevel -lt 1) {
      foreach ($sub in $subNames) { Show-Shape -Value $Value.$sub -Name $sub -IndentLevel ($IndentLevel + 1) }
    }
  }
  elseif ($IndentLevel -lt 1) {
    # Only trust a bare scalar at the TOP level to be safe metadata (a status
    # code, say) rather than a tracker field. A scalar found one level down -
    # e.g. queue.company if "queue" turned out to be a single row object
    # instead of a named group of lists - could be an actual row value, so it
    # never prints past this point.
    Write-Host "$indent- $Name : $Value"
  }
  else {
    $typeName = if ($null -eq $Value) { 'null' } else { $Value.GetType().Name }
    Write-Host "$indent- $Name : (value hidden, type $typeName - too deep to be trusted as non-row data)"
  }
}

Write-Host ""
Write-Host "Response shape (values only shown for plain scalars like a status code):"
foreach ($name in @($response.PSObject.Properties.Name)) {
  Show-Shape -Value $response.$name -Name $name -IndentLevel 0
}
Write-Host ""
Write-Host "Report back everything printed above - nothing else needed."
Write-Host ""

$response = $null

exit 0
