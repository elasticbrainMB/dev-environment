# One-off setup for Task B's timer proof (PHASE2-CLOSEOUT-timer-and-spendcap.md).
# Creates two Windows Scheduled Tasks, both running whether Matt is logged on
# or not, via S4U logon - no password ever stored or entered. Throwaway:
# teardown-timer-proof-tasks.ps1 removes both once the proof is observed.

param(
  [datetime]$RunJobStart = (Get-Date -Hour 23 -Minute 0 -Second 0),
  [datetime]$HeartbeatStart = (Get-Date -Hour 23 -Minute 5 -Second 0),
  [int]$RepeatMinutes = 10,
  [int]$DurationHours = 3
)

$ErrorActionPreference = 'Stop'

$root = 'C:\automation\dev-environment\proving-ground'
$account = "$env:USERDOMAIN\$env:USERNAME"
$duration = New-TimeSpan -Hours $DurationHours
$interval = New-TimeSpan -Minutes $RepeatMinutes

function Register-ProvingGroundTask {
  param(
    [string]$TaskName,
    [string]$ScriptPath,
    [string]$Arguments,
    [datetime]$StartTime
  )

  if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Host "Task '$TaskName' already exists - removing it first."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
  }

  $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" $Arguments" `
    -WorkingDirectory $root

  $trigger = New-ScheduledTaskTrigger -Once -At $StartTime `
    -RepetitionInterval $interval -RepetitionDuration $duration

  $principal = New-ScheduledTaskPrincipal -UserId $account -LogonType S4U -RunLevel Limited

  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew

  Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -ErrorAction Stop | Out-Null

  # Register-ScheduledTask has been seen to report a non-terminating error
  # (e.g. Access is denied) and let the script carry on - confirm the task is
  # actually there before calling it a success.
  if (-not (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)) {
    throw "Register-ScheduledTask did not throw, but '$TaskName' does not exist afterward - treat this as failed."
  }

  Write-Host "Registered '$TaskName': first fire $($StartTime.ToString('yyyy-MM-dd HH:mm')), every $RepeatMinutes min for $DurationHours h."
}

Register-ProvingGroundTask -TaskName 'proving-ground-run-job' `
  -ScriptPath (Join-Path $root 'run-job.ps1') -Arguments '' -StartTime $RunJobStart

Register-ProvingGroundTask -TaskName 'proving-ground-heartbeat-check' `
  -ScriptPath (Join-Path $root 'check-heartbeat.ps1') -Arguments '-MaxAgeMinutes 15' -StartTime $HeartbeatStart

Write-Host ""
Write-Host "Both tasks run as $account, whether logged on or not (S4U - no password stored)."
Write-Host "Working directory for both: $root"
