param()
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$sources = @(
  (Join-Path $root "mql\Experts\ExpectedValue_MultiCurrency_TickShockResearch.mq5")
)
$sources += Get-ChildItem (Join-Path $root "mql\Experts\tests\ExpectedValue_TickShock_*Harness.mq5") |
  Sort-Object Name | Select-Object -ExpandProperty FullName
$rows = @()
foreach ($source in $sources) {
  $target = [IO.Path]::GetFileNameWithoutExtension($source)
  $log = Join-Path $root "reports\compile\tick_shock\step15c_$target.log"
  & (Join-Path $root "scripts\compile.ps1") -Source $source -LogPath $log
  $text = Get-Content -LiteralPath $log -Raw
  $match = [regex]::Match($text, 'Result:\s+(\d+) errors?,\s+(\d+) warnings?')
  $errors = if ($match.Success) { [int]$match.Groups[1].Value } else { -1 }
  $warnings = if ($match.Success) { [int]$match.Groups[2].Value } else { -1 }
  $rows += [pscustomobject]@{
    target = $target
    source = $source.Substring($root.Length + 1).Replace('\','/')
    log_path = $log.Substring($root.Length + 1).Replace('\','/')
    errors = $errors
    warnings = $warnings
    status = if ($errors -eq 0 -and $warnings -eq 0) { 'PASS' } else { 'FAIL' }
  }
}
$result = Join-Path $root "reports\compile\tick_shock\step15c_compile_results.csv"
$rows | Export-Csv -LiteralPath $result -NoTypeInformation -Encoding utf8
$failed = @($rows | Where-Object status -ne 'PASS').Count
Write-Host "targets=$($rows.Count) failures=$failed"
if ($failed -ne 0) { exit 1 }
