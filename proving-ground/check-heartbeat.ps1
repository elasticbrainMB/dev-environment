# The dead-man's check for the proving-ground timer proof. Runs as its own
# scheduled task, independent of run-job.ps1 and of the openclaw container -
# it must still work when openclaw is down, since that's exactly the failure
# it exists to catch. Alerts via infra-watch's Discord webhook script, which
# posts straight to Discord over HTTP and never touches docker.

param(
  [int]$MaxAgeMinutes = 15
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$root             = 'C:\automation\dev-environment\proving-ground'
$heartbeatPath    = Join-Path $root 'heartbeat.txt'
$checkLogPath     = Join-Path $root 'heartbeat-check-log.txt'
$postDiscordDirect = 'C:\automation\infra-watch\scripts\post-discord.ps1'

function Write-CheckLog {
  param([string]$Line)
  $stamped = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $Line"
  Add-Content -Path $checkLogPath -Value $stamped -Encoding utf8
  Write-Output $stamped
}

if (-not (Test-Path $heartbeatPath)) {
  Write-CheckLog "STALE: no heartbeat file found at $heartbeatPath - run-job.ps1 may never have started."
  & $postDiscordDirect -Channel 'decisions' -Message "[proving-ground] dead-man's check: no heartbeat file found. run-job.ps1 may never have started." -Title 'proving-ground SILENT'
  exit 1
}

$lastBeat = [datetime]::Parse((Get-Content -Path $heartbeatPath -Raw -Encoding utf8).Trim())
$ageMinutes = [math]::Round(((Get-Date) - $lastBeat).TotalMinutes, 1)

if ($ageMinutes -gt $MaxAgeMinutes) {
  Write-CheckLog "STALE: heartbeat is $ageMinutes minutes old (limit $MaxAgeMinutes) - last beat $($lastBeat.ToString('o'))."
  & $postDiscordDirect -Channel 'decisions' -Message "[proving-ground] dead-man's check: heartbeat is $ageMinutes minutes old (limit $MaxAgeMinutes). Last beat: $($lastBeat.ToString('o')). run-job.ps1 may be hung or unable to reach docker." -Title 'proving-ground SILENT'
  exit 1
}

Write-CheckLog "OK: heartbeat is $ageMinutes minutes old (limit $MaxAgeMinutes)."
exit 0
