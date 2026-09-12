$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$root            = 'C:\automation\dev-environment\proving-ground'
$statePath       = Join-Path $root 'state.json'
$inputPath       = Join-Path $root 'input.txt'
$verifyScript    = Join-Path $root 'verify-proving-ground.ps1'
$runLogPath      = Join-Path $root 'run-log.txt'
$utf8NoBom       = New-Object System.Text.UTF8Encoding($false)

$container       = 'openclaw'
$agentId         = 'automation'
$containerWsDir  = '/home/node/.openclaw/agents/automation/workspace/proving-ground'
$localModel      = 'ollama/qwen3.5:9b-q8_0'
$paidModel       = 'openrouter/~anthropic/claude-sonnet-latest'
$emitToken       = '[PG-OK]'
$maxWords        = 25
$hardStopAt      = 5
$alertsChannel   = 'channel:1529976260007301242'   # #alerts - quiet, every run
$decisionsChannel = 'channel:1540419837086404668'  # #decisions - pings, needs-Matt only
$heartbeatPath   = Join-Path $root 'heartbeat.txt'
$postDiscordDirect = 'C:\automation\infra-watch\scripts\post-discord.ps1'  # host-side webhook, no docker dependency

function Write-Log {
  param([string]$Line)
  $stamped = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $Line"
  Add-Content -Path $runLogPath -Value $stamped -Encoding utf8
  Write-Output $stamped
}

function Get-State {
  if (-not (Test-Path $statePath)) {
    return [PSCustomObject]@{
      status        = 'running'
      attempt       = 0
      requiredToken = $emitToken
      totalCostUsd  = 0.0
      stoppedAt     = $null
      stopReason    = $null
      history       = @()
    }
  }
  $raw = Get-Content -Path $statePath -Raw -Encoding utf8
  return $raw | ConvertFrom-Json
}

function Save-State {
  param($State)
  $json = $State | ConvertTo-Json -Depth 10
  [System.IO.File]::WriteAllText($statePath, $json, $utf8NoBom)
}

function Send-Discord {
  param([string]$Channel, [string]$Message)
  # Under $ErrorActionPreference = 'Stop', a native command's stderr becomes
  # a terminating error the instant it's touched by ANY '2>' redirect (even
  # 2>$null) - relaxing EAP for just this call is the only pattern that both
  # avoids the throw and still lets the exit code/output be inspected.
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & docker exec $container openclaw message send --channel discord --target $Channel --message $Message --json 2>&1 | Out-Null
  $ErrorActionPreference = $prevEap
  if ($LASTEXITCODE -ne 0) { Write-Log "WARN: discord post to $Channel failed (exit $LASTEXITCODE)" }
}

# Written before anything that can throw or hang (docker included) - the one
# signal that survives even when this session can't reach docker or Discord.
# A separate scheduled check (check-heartbeat.ps1) alerts if this goes stale.
[System.IO.File]::WriteAllText($heartbeatPath, (Get-Date).ToString('o'), $utf8NoBom)

try {

$state = Get-State

if ($state.status -eq 'stopped') {
  Write-Log "SKIP: job is stopped (since $($state.stoppedAt)) - no restart on scheduled tick."
  exit 0
}

$attempt   = [int]$state.attempt + 1
$model     = if ($attempt -le 2) { $localModel } else { $paidModel }
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outputRel = "output-$timestamp.txt"
$hostOutputPath = Join-Path $root $outputRel

Write-Log "START attempt $attempt/$hardStopAt using $model"

# Same reason as Send-Discord above: relax EAP around every docker call in
# this block, since the container being unreachable (the exact scenario this
# whole job exists to survive) is what makes these throw.
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& docker exec $container sh -lc "mkdir -p $containerWsDir" 2>&1 | Out-Null
Get-Content -Path $inputPath -Raw -Encoding utf8 | & docker exec -i $container sh -lc "cat > $containerWsDir/input.txt" 2>&1 | Out-Null
$ErrorActionPreference = $prevEap

$message = "This is an automated proving-ground test run (attempt $attempt of $hardStopAt). " +
  "Read the file proving-ground/input.txt in your workspace. " +
  "Write a one-line summary of it, no more than $($maxWords - 3) words, ending with the exact literal token $emitToken, " +
  "to a new file at proving-ground/$outputRel in your workspace. Do nothing else: no other files, no other tools, no reply needed."

$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$agentRaw = & docker exec $container openclaw agent --agent $agentId --model $model --message $message --json 2>&1
$ErrorActionPreference = $prevEap
$agentExit = $LASTEXITCODE

$costUsd = 0.0
$agentOk = $false
if ($agentExit -eq 0) {
  try {
    $agentJson = $agentRaw | ConvertFrom-Json
    $agentOk = ($agentJson.status -eq 'ok')
    if ($agentJson.result.meta.agentMeta.costUsd) { $costUsd = [double]$agentJson.result.meta.agentMeta.costUsd }
  } catch {
    Write-Log "WARN: could not parse agent JSON response: $($_.Exception.Message)"
  }
} else {
  Write-Log "WARN: agent invocation failed, exit $agentExit"
  Write-Log ($agentRaw -join "`n")
}

$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& docker exec $container sh -lc "cat $containerWsDir/$outputRel 2>/dev/null" 2>$null | Set-Content -Path $hostOutputPath -Encoding utf8 -NoNewline
$ErrorActionPreference = $prevEap

$verifyOutput = & powershell.exe -NoProfile -File $verifyScript -OutputPath $hostOutputPath -RequiredToken $state.requiredToken -MaxWords $maxWords 2>&1
$verifyExit = $LASTEXITCODE
$pass = ($agentOk -and $verifyExit -eq 0)
$summaryLine = ($verifyOutput | Select-String '^SUMMARY:').ToString()
if (-not $summaryLine) { $summaryLine = "agent-error or no verify output (agentOk=$agentOk, verifyExit=$verifyExit)" }

$state.totalCostUsd = [double]$state.totalCostUsd + $costUsd
$historyEntry = [PSCustomObject]@{
  attempt   = $attempt
  timestamp = $timestamp
  model     = $model
  result    = if ($pass) { 'pass' } else { 'fail' }
  costUsd   = $costUsd
  summary   = $summaryLine
}
$state.history = @($state.history) + $historyEntry

if ($pass) {
  Write-Log "PASS attempt $attempt via $model - $summaryLine"
  $state.attempt = 0
  Save-State $state
  Send-Discord -Channel $alertsChannel -Message "[proving-ground] attempt $attempt PASS via $model. $summaryLine"
}
elseif ($attempt -lt $hardStopAt) {
  Write-Log "FAIL attempt $attempt via $model (no progress) - $summaryLine"
  $state.attempt = $attempt
  Save-State $state
  Send-Discord -Channel $alertsChannel -Message "[proving-ground] attempt $attempt FAIL via $model (no progress). $summaryLine"
}
else {
  Write-Log "STOP after $attempt consecutive no-progress attempts - $summaryLine"
  $state.status     = 'stopped'
  $state.attempt    = $attempt
  $state.stoppedAt  = (Get-Date).ToString('o')
  $state.stopReason = "5 consecutive no-progress attempts. Last check: $summaryLine"

  $reportPath = Join-Path $root "report-stopped-$timestamp.md"
  $reportLines = @(
    "# Proving-ground stop report",
    "",
    "Stopped: $($state.stoppedAt)",
    "Reason: $($state.stopReason)",
    "Total spend so far: `$$($state.totalCostUsd)",
    "",
    "## Attempt history",
    ""
  )
  foreach ($h in $state.history) {
    $reportLines += "- attempt $($h.attempt) ($($h.model)): $($h.result) - $($h.summary) - cost `$$($h.costUsd)"
  }
  $reportLines += @("", "Job will not restart on its next scheduled tick. Clear state.json's status to resume.")
  [System.IO.File]::WriteAllText($reportPath, ($reportLines -join "`n"), $utf8NoBom)

  Save-State $state
  Send-Discord -Channel $alertsChannel -Message "[proving-ground] STOPPED after $attempt attempts. Report: $(Split-Path $reportPath -Leaf)"
  Send-Discord -Channel $decisionsChannel -Message "[proving-ground] needs Matt - stopped after 5 consecutive no-progress attempts. Report: $(Split-Path $reportPath -Leaf). Will not restart until state.json is cleared."
}

exit 0

}
catch {
  # Extra safety net, not a substitute for the heartbeat: this can't fire if
  # docker itself is what's broken, since both logging paths below may also
  # depend on it having worked at some point. Try both anyway - each is
  # independent of the other, so one failing doesn't take down the other.
  $errMsg = $_.Exception.Message
  try { Write-Log "FATAL: unhandled error - $errMsg" } catch {}
  try { Send-Discord -Channel $alertsChannel -Message "[proving-ground] FATAL error in run-job.ps1: $errMsg" } catch {}
  try { & $postDiscordDirect -Channel 'decisions' -Message "[proving-ground] run-job.ps1 crashed: $errMsg" -Title 'proving-ground FATAL' 2>&1 | Out-Null } catch {}
  exit 1
}
