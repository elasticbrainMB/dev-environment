# Run once, by Matt, in his own PowerShell window. Creates the $5/week
# capped OpenRouter key that OpenClaw's escalation path will use. Needs the
# OpenRouter Management API key, which this script never writes to disk and
# never prints unless the automated hand-off into OpenClaw's credential
# store fails.

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$container = 'openclaw'
$keyName   = 'openclaw-automation'
$weeklyLimit = 5

function ConvertFrom-SecureStringPlain {
  param([Parameter(Mandatory)][System.Security.SecureString]$Secure)
  return [System.Net.NetworkCredential]::new('', $Secure).Password
}

function Send-KeyViaStdin {
  # Tries to hand the new key to OpenClaw's credential store without ever
  # printing it. Returns $true only on a clean, confirmed success.
  param(
    [Parameter(Mandatory)][string]$Container,
    [Parameter(Mandatory)][string]$PlainKey,
    [int]$TimeoutMs = 15000
  )

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName  = 'docker'
  $psi.Arguments = "exec -i $Container openclaw models auth paste-api-key --provider openrouter --agent main"
  $psi.RedirectStandardInput  = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false

  $proc = $null
  try {
    $proc = [System.Diagnostics.Process]::Start($psi)
  } catch {
    return $false
  }

  try {
    $proc.StandardInput.WriteLine($PlainKey)
    $proc.StandardInput.Close()
  } catch {
    try { $proc.Kill() } catch {}
    return $false
  }

  $exited = $proc.WaitForExit($TimeoutMs)
  if (-not $exited) {
    try { $proc.Kill() } catch {}
    return $false
  }

  return ($proc.ExitCode -eq 0)
}

Write-Host ""
Write-Host "This creates a new OpenRouter API key named '$keyName', capped at" "`$$weeklyLimit/week."
Write-Host "It needs your OpenRouter MANAGEMENT key - the account-wide one, not the capped key."
Write-Host ""

$secureManagementKey = Read-Host -Prompt 'OpenRouter Management API key (input hidden)' -AsSecureString
$managementKeyPlain  = ConvertFrom-SecureStringPlain -Secure $secureManagementKey

$capKeyPlain = $null
$response    = $null

try {
  $bodyJson = @{
    name        = $keyName
    limit       = $weeklyLimit
    limit_reset = 'weekly'
  } | ConvertTo-Json

  try {
    $response = Invoke-RestMethod -Method Post -Uri 'https://openrouter.ai/api/v1/keys' `
      -Headers @{ Authorization = "Bearer $managementKeyPlain" } `
      -ContentType 'application/json' `
      -Body $bodyJson
  } catch {
    $detail = if ($_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
    Write-Host ""
    Write-Host "Key creation failed: $detail" -ForegroundColor Red
    exit 1
  }
}
finally {
  # The management key has done its only job for this run - drop it now,
  # win or lose, rather than holding it until script exit.
  $managementKeyPlain = $null
  $secureManagementKey = $null
}

if (-not $response.key) {
  Write-Host ""
  Write-Host "Key creation call succeeded but no key was returned - nothing to hand off. Check the OpenRouter dashboard before retrying." -ForegroundColor Red
  exit 1
}

$capKeyPlain = $response.key

$handedOff = Send-KeyViaStdin -Container $container -PlainKey $capKeyPlain

# OpenRouter shows a key's value exactly once, at creation - this is the only
# chance to get a copy into the password manager, so show it regardless of
# whether the automated hand-off into OpenClaw worked.
Write-Host ""
if ($handedOff) {
  Write-Host "OpenClaw already has this key (handed off automatically)." -ForegroundColor Yellow
  Write-Host "Copy it below into your password manager now - OpenRouter only shows it this once:" -ForegroundColor Yellow
} else {
  Write-Host "Could not hand the new key to OpenClaw's credential store automatically" -ForegroundColor Yellow
  Write-Host "(paste-api-key looks like it needs an interactive prompt). Do it yourself:" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "  1. Copy the key below into your password manager now." -ForegroundColor Yellow
  Write-Host "  2. Run this yourself, and paste the key when it prompts:" -ForegroundColor Yellow
  Write-Host "       docker exec -it $container openclaw models auth paste-api-key --provider openrouter --agent main" -ForegroundColor Yellow
}
Write-Host ""
Write-Host $capKeyPlain -ForegroundColor Cyan
Write-Host ""
$doneNote = if ($handedOff) { "Press Enter once it's copied." } else { "Press Enter once it's copied and step 2 above is done." }
Write-Host "$doneNote This screen will clear."
Read-Host | Out-Null
Clear-Host

$capKeyPlain = $null

$limit         = $response.data.limit
$limitReset    = $response.data.limit_reset
$limitRemaining = if ($null -ne $response.data.limit_remaining) { $response.data.limit_remaining } else { $limit }

Write-Host ""
Write-Host "Capped key '$($response.data.name)' created."
Write-Host "  limit:           $limit"
Write-Host "  limit_reset:     $limitReset"
Write-Host "  limit_remaining: $limitRemaining"
Write-Host ""
Write-Host "Done. Two things left, both yours:"
Write-Host ""
Write-Host "  1. Save the capped key in your password manager (Bitwarden/1Password/"
Write-Host "     similar - NOT a .env file). It is the key OpenClaw now uses to pay"
Write-Host "     for escalated model calls. Capped at `$$weeklyLimit/week."
Write-Host ""
Write-Host "  2. DELETE the management key you just used, at"
Write-Host "     https://openrouter.ai/settings/management-keys"
Write-Host "     It can create and delete keys on your whole account and it has now"
Write-Host "     done its only job. The capped key is not affected."
Write-Host ""
Write-Host "Report back to Claude Code: limit, limit_reset, limit_remaining (above)."
Write-Host "Do not paste either key."
Write-Host ""

$response = $null

exit 0
