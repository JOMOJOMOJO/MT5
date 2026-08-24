$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$manifestPath = Join-Path $repoRoot "docs\research\tick_shock\00_artifact_manifest.md"
$lines = [System.Collections.Generic.List[string]](Get-Content -LiteralPath $manifestPath -Encoding UTF8)
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -eq '- status: `STEP11_PRE_FIX_RED_ROLLUP`') { $lines[$i] = '- status: `STEP12_POST_FIX_GREEN_ROLLUP`' }
    elseif ($lines[$i] -eq '- manifest_revision: `11`') { $lines[$i] = '- manifest_revision: `12`' }
    elseif ($lines[$i] -eq '- covered_steps: `01-11`') { $lines[$i] = '- covered_steps: `01-12`' }
    elseif ($lines[$i] -like '- last_audited_commit:*') { $lines[$i] = '- last_audited_commit: `6bbc0be2`' }
    elseif ($lines[$i] -like '- last_updated_at:*') { $lines[$i] = '- last_updated_at: `2026-08-24T18:00:00+09:00`' }
}

$paths = [System.Collections.Generic.List[string]]::new()
foreach ($path in @(
    "mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5",
    "mql/Include/TickShock/TickShockTypes.mqh", "mql/Include/TickShock/TickShockConfig.mqh",
    "mql/Include/TickShock/TickShockMetrics.mqh", "mql/Include/TickShock/TickShockEventEngine.mqh",
    "mql/Include/TickShock/TickShockMergeSequencer.mqh", "mql/Include/TickShock/TickShockScenarioEngine.mqh",
    "mql/Include/TickShock/TickShockCsvSerializer.mqh", "mql/Include/TickShock/TickShockOrderLifecycle.mqh",
    "mql/Include/TickShock/TickShockEngine.mqh", "mql/Include/TickShock/TickShockMt5Adapter.mqh",
    "mql/Experts/tests/TickShockStep5TestSupport.mqh",
    "tools/tick_shock/run_mql_harnesses.ps1", "tools/tick_shock/run_python_tests.py",
    "tools/tick_shock/extract_mql_functions.py", "tools/tick_shock/build_step12_evidence.py",
    "tools/tick_shock/update_step12_manifest.ps1", "tests/tick_shock/python/conftest.py",
    "docs/research/tick_shock/02_function_catalog.md", "docs/research/tick_shock/02_data_structures_and_globals.md",
    "docs/research/tick_shock/03_requirements_traceability.md", "docs/research/tick_shock/12_engineering_fix.md",
    "docs/devlog/2026-08-24-tickshock-step12-fail-closed-integrity.md",
    "reports/tests/tick_shock/step12_post_fix_results.csv", "reports/tests/tick_shock/step12_post_fix_green_report.md",
    "reports/tests/tick_shock/step12_python_tests.log",
    "reports/qa/tick_shock/step12_fixture_integrity.csv", "reports/qa/tick_shock/step12_behavior_preservation.csv",
    "reports/qa/tick_shock/step12_strategy_parameter_integrity.csv", "reports/qa/tick_shock/step12_function_extraction.csv",
    "reports/qa/tick_shock/step12_functions_step10.csv"
)) { $paths.Add($path) }
foreach ($spec in @(
    @{Root="reports\tests\tick_shock\step12_raw"; Filter="*"},
    @{Root="reports\tests\tick_shock\configs"; Filter="step12_*"},
    @{Root="reports\tests\tick_shock\tester"; Filter="step12_*"},
    @{Root="reports\compile\tick_shock"; Filter="step12_*"}
)) {
    foreach ($file in Get-ChildItem (Join-Path $repoRoot $spec.Root) -File -Filter $spec.Filter) {
        $paths.Add($file.FullName.Substring($repoRoot.Length + 1).Replace('\','/'))
    }
}

$existingPaths=@{}
$sequence=0
foreach($line in $lines)
  {
   if($line -match '^\| TS-S12-(\d+) \|') {$sequence=[Math]::Max($sequence,[int]$Matches[1])}
   if($line -match '^\| TS-S12-\d+ \| 12 \| `([^`]+)` \|') {$existingPaths[$Matches[1]]=$lines.IndexOf($line)}
  }
foreach ($relative in $paths | Sort-Object -Unique) {
    $absolute = Join-Path $repoRoot $relative
    if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) { throw "Missing Step 12 artifact: $relative" }
    $sha = (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash
    if($existingPaths.ContainsKey($relative))
      {
       $index=[int]$existingPaths[$relative];$parts=$lines[$index] -split '\|';$parts[7]=" ``$sha`` ";$lines[$index]=$parts -join '|';continue
      }
    $sequence++
    $id = "TS-S12-{0:D3}" -f $sequence
    if ($lines -match "\| $id \|") { throw "Duplicate artifact ID: $id" }
    $kind = if ($relative -match 'step12_raw|results|compile|tester') { "generated evidence" } elseif ($relative -match '\.(mq5|mqh|py|ps1)$') { "source" } else { "document/evidence" }
    $lines.Add("| $id | 12 | ``$relative`` | $kind | Step 12 fail-closed GREEN evidence | $kind | ``$sha`` | yes | Step 13 | COMPLETE | immutable Step 11 oracle preserved | SELF |")
}
[System.IO.File]::WriteAllLines($manifestPath,$lines,[System.Text.UTF8Encoding]::new($false))
Write-Host "Step 12 manifest sequence now $sequence."
