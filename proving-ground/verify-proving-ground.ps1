param(
  [Parameter(Mandatory)][string]$OutputPath,
  [Parameter(Mandatory)][string]$RequiredToken,
  [int]$MaxWords = 25
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$results = New-Object System.Collections.ArrayList
function Add-Result {
  param([string]$Check, [bool]$Pass, [string]$Reason)
  [void]$results.Add([PSCustomObject]@{ Check = $Check; Pass = $Pass; Reason = $Reason })
}

$exists = Test-Path $OutputPath -PathType Leaf
Add-Result 'output-exists' $exists $(if ($exists) { $OutputPath } else { "not found: $OutputPath" })

$text = ''
if ($exists) {
  $text = (Get-Content -Path $OutputPath -Raw -Encoding utf8)
  if ($null -eq $text) { $text = '' }
}
$trimmed = $text.Trim()

$nonEmpty = $trimmed.Length -gt 0
Add-Result 'output-non-empty' $nonEmpty $(if ($nonEmpty) { "$($trimmed.Length) chars" } else { 'file is empty or whitespace-only' })

$wordCount = 0
if ($nonEmpty) { $wordCount = @($trimmed -split '\s+' | Where-Object { $_ -ne '' }).Count }
$underLimit = $nonEmpty -and ($wordCount -le $MaxWords)
Add-Result 'output-word-count' $underLimit "$wordCount words (limit $MaxWords)"

$hasToken = $nonEmpty -and $trimmed.Contains($RequiredToken)
Add-Result 'output-has-required-token' $hasToken $(if ($hasToken) { "found '$RequiredToken'" } else { "'$RequiredToken' not found" })

Write-Host ""
Write-Host "verify-proving-ground.ps1 - Output: $OutputPath"
Write-Host ""
$results | Format-Table Check, Pass, Reason -AutoSize

$failures = @($results | Where-Object { -not $_.Pass })
Write-Output "SUMMARY: $($results.Count) checks run. Failures: $($failures.Count)."
if ($failures.Count -gt 0) { exit 1 } else { exit 0 }
