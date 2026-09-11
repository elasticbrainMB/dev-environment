# Setup for Task B's timer proof (PHASE2-CLOSEOUT-timer-and-spendcap.md, B3b).
# Registers every intervention as its own Windows Scheduled Task, so the
# whole overnight sequence runs with nobody present - not Matt, not an agent.
# Idempotent: re-running this safely replaces any of the five tasks below
# that already exist, so it can be run again over an earlier attempt.
#
# Deliberately avoids Disable-ScheduledTask/Enable-ScheduledTask at runtime:
# registering a task already needed an elevated session once (see the A2
# retry in this project's history), and a Limited-run-level task firing at
# 1am with nobody around to fix a second "Access is denied" is not a risk
# worth taking. Instead, proving-ground-run-job's own repetition DURATION is
# shortened so it stops ticking naturally right after producing the evidence
# B3b wants - no runtime task-modification calls needed at all. The only
# actions the one-time tasks take are `docker stop`/`docker start`, which
# this same non-interactive S4U context has already run successfully all
# evening via run-job.ps1's own docker exec calls.
#
# Teardown (B5) is deliberately NOT scheduled here - Matt reviews the
# evidence first; see PHASE2-CLOSEOUT-timer-and-spendcap.md.

param(
  [datetime]$RunJobStart = (Get-Date -Hour 23 -Minute 0 -Second 0),
  [datetime]$HeartbeatStart = (Get-Date -Hour 23 -Minute 5 -Second 0),
  [datetime]$BreakContainerAt = (Get-Date -Hour 23 -Minute 52 -Second 0),
  [datetime]$RestoreContainerAt = (Get-Date -Hour 1 -Minute 0 -Second 0).AddDays(1),
  [int]$RepeatMinutes = 10,
  [int]$RunJobDurationHours = 2,
  [int]$HeartbeatDurationHours = 3,
  [int]$HeartbeatMaxAgeMinutes = 15
)

$ErrorActionPreference = 'Stop'

$root = 'C:\automation\dev-environment\proving-ground'
$account = "$env:USERDOMAIN\$env:USERNAME"
$interval = New-TimeSpan -Minutes $RepeatMinutes

function Test-TaskExists {
  param([string]$TaskName)
  return [bool](Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)
}

function Remove-IfExists {
  param([string]$TaskName)
  if (Test-TaskExists $TaskName) {
    Write-Host "Task '$TaskName' already exists - removing it first."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
  }
}

function Confirm-Registered {
  param([string]$TaskName)
  # Register-ScheduledTask has been seen to report a non-terminating error
  # (e.g. Access is denied) and let the script carry on - confirm the task is
  # actually there before calling it a success.
  if (-not (Test-TaskExists $TaskName)) {
    throw "Register-ScheduledTask did not throw, but '$TaskName' does not exist afterward - treat this as failed."
  }
}

function Register-ProvingGroundTask {
  param(
    [string]$TaskName,
    [string]$ScriptPath,
    [string]$Arguments,
    [datetime]$StartTime,
    [timespan]$Duration
  )

  Remove-IfExists $TaskName

  $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" $Arguments" `
    -WorkingDirectory $root

  $trigger = New-ScheduledTaskTrigger -Once -At $StartTime `
    -RepetitionInterval $interval -RepetitionDuration $Duration

  $principal = New-ScheduledTaskPrincipal -UserId $account -LogonType S4U -RunLevel Limited

  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew

  Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -ErrorAction Stop | Out-Null

  Confirm-Registered $TaskName

  $lastFire = $StartTime.Add($Duration)
  Write-Host "Registered '$TaskName': fires $($StartTime.ToString('yyyy-MM-dd HH:mm')) then every $RepeatMinutes min, last occurrence before $($lastFire.ToString('HH:mm'))."
}

function Register-OneTimeCommandTask {
  param(
    [string]$TaskName,
    [string]$Command,
    [datetime]$At
  )

  Remove-IfExists $TaskName

  $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$Command`"" `
    -WorkingDirectory $root

  $trigger = New-ScheduledTaskTrigger -Once -At $At

  $principal = New-ScheduledTaskPrincipal -UserId $account -LogonType S4U -RunLevel Limited

  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable

  Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -ErrorAction Stop | Out-Null

  Confirm-Registered $TaskName

  Write-Host "Registered '$TaskName': fires once at $($At.ToString('yyyy-MM-dd HH:mm')) - runs: $Command"
}

Register-ProvingGroundTask -TaskName 'proving-ground-run-job' `
  -ScriptPath (Join-Path $root 'run-job.ps1') -Arguments '' `
  -StartTime $RunJobStart -Duration (New-TimeSpan -Hours $RunJobDurationHours)

Register-ProvingGroundTask -TaskName 'proving-ground-heartbeat-check' `
  -ScriptPath (Join-Path $root 'check-heartbeat.ps1') -Arguments "-MaxAgeMinutes $HeartbeatMaxAgeMinutes" `
  -StartTime $HeartbeatStart -Duration (New-TimeSpan -Hours $HeartbeatDurationHours)

Register-OneTimeCommandTask -TaskName 'proving-ground-break-container' `
  -Command 'docker stop openclaw' -At $BreakContainerAt

Register-OneTimeCommandTask -TaskName 'proving-ground-restore-container' `
  -Command 'docker start openclaw' -At $RestoreContainerAt

Write-Host ""
Write-Host "All four tasks run as $account, whether logged on or not (S4U - no password stored)."
Write-Host "Working directory for the two repeating tasks: $root"
