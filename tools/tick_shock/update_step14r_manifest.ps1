param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"
$manifestPath = Join-Path $RepoRoot "docs\research\tick_shock\00_artifact_manifest.md"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$text = [System.IO.File]::ReadAllText($manifestPath, $utf8NoBom)
$text = [regex]::Replace($text, '(?s)\r?\n## Step 14R pre-Step-15 remediation artifacts.*$', '')
$text = [regex]::Replace($text, '(?m)^- status: `[^`]+`\r?$', '- status: `STEP14R_PRE_STEP15_REMEDIATION_COMPLETE`')
$text = [regex]::Replace($text, '(?m)^- manifest_revision: `[^`]+`\r?$', '- manifest_revision: `14R`')
$text = [regex]::Replace($text, '(?m)^- covered_steps: `[^`]+`\r?$', '- covered_steps: `01-14R`')
$text = [regex]::Replace($text, '(?m)^- last_audited_commit: `[^`]+`\r?$', '- last_audited_commit: `d454622786795a85c21e16a4d154440eef80b48f`')
$text = [regex]::Replace($text, '(?m)^- last_updated_at: `[^`]+`\r?$', '- last_updated_at: `2026-08-25T02:30:00+09:00`')

$paths = [System.Collections.Generic.List[string]]::new()
foreach ($relative in @(
    'mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5',
    'mql/Experts/tests/ExpectedValue_TickShock_IntegrityRegressionHarness.mq5',
    'mql/Experts/tests/ExpectedValue_TickShock_MultiCurrencyMergeHarness.mq5',
    'mql/Experts/tests/ExpectedValue_TickShock_OrderReachabilityHarness.mq5',
    'mql/Experts/tests/TickShockStep5TestSupport.mqh',
    'mql/Include/TickShock/TickShockCsvSerializer.mqh',
    'mql/Include/TickShock/TickShockMergeSequencer.mqh',
    'mql/Include/TickShock/TickShockMt5Adapter.mqh',
    'mql/Include/TickShock/TickShockOrderLifecycle.mqh',
    'mql/Include/TickShock/TickShockTypes.mqh',
    'docs/research/tick_shock/02_data_structures_and_globals.md',
    'docs/research/tick_shock/02_function_catalog.md',
    'docs/research/tick_shock/03_requirements_traceability.md',
    'docs/research/tick_shock/03_test_oracle_calculation.md',
    'docs/research/tick_shock/03_test_specification.md',
    'docs/research/tick_shock/11_test_oracle_addendum.md',
    'docs/research/tick_shock/13_order_observation.md',
    'docs/research/tick_shock/14_march_revalidation.md',
    'docs/research/tick_shock/14r_pre_step15_remediation.md',
    'docs/research/tick_shock_scalper_csv_schema.md',
    'docs/devlog/2026-08-25-tickshock-step14r-remediation.md',
    'tests/tick_shock/spec/test_cases.csv',
    'tools/tick_shock/build_step13_hashes.py',
    'tools/tick_shock/build_step13_order_observation.py',
    'tools/tick_shock/build_step14r_qa_evidence.py',
    'tools/tick_shock/compare_step14r_replays.py',
    'tools/tick_shock/prepare_step14r_run_evidence.py',
    'tools/tick_shock/reconcile_causal_runs.py',
    'tools/tick_shock/run_all_tests.ps1',
    'tools/tick_shock/run_mql_harnesses.ps1',
    'tools/tick_shock/run_python_tests.py',
    'tools/tick_shock/run_step14r_validator_negative_tests.py',
    'tools/tick_shock/update_step14r_manifest.ps1',
    'reports/qa/tick_shock/step14r_changed_files.csv',
    'reports/qa/tick_shock/step14r_function_extraction.csv',
    'reports/qa/tick_shock/step14r_source_hashes.txt',
    'reports/qa/tick_shock/step14r_strategy_parameter_comparison.csv'
)) { $paths.Add($relative) }

foreach ($testId in @('TS-MERGE-003','TS-MERGE-004','TS-MERGE-005','TS-ORDER-008','TS-ORDER-009')) {
    foreach ($suffix in @("fixtures/${testId}_ticks.csv", "fixtures/${testId}_config.csv", "expected/${testId}_expected.csv")) {
        $paths.Add("tests/tick_shock/$suffix")
    }
}

foreach ($spec in @(
    @{ Root='reports\tests\tick_shock\step14r_pre_fix'; Filter='*' },
    @{ Root='reports\tests\tick_shock\step14r_post_fix'; Filter='*' },
    @{ Root='reports\tests\tick_shock\step14r_transient_recovery_pre_fix'; Filter='*' },
    @{ Root='reports\tests\tick_shock\step14r_transient_recovery_post_fix'; Filter='*' },
    @{ Root='reports\tests\tick_shock\step14r_final'; Filter='*' },
    @{ Root='reports\tests\tick_shock\step14r_order_observation_final'; Filter='*' },
    @{ Root='reports\backtest\runs\20260825_ts14r3_ideal_202503'; Filter='*' },
    @{ Root='reports\backtest\runs\20260825_ts14r3_realizable_202503'; Filter='*' },
    @{ Root='reports\backtest\runs\20260825_ts14r3_comparison_202503'; Filter='*' },
    @{ Root='reports\compile\tick_shock'; Filter='step14r_ExpectedValue_*.log' }
)) {
    $root = Join-Path $RepoRoot $spec.Root
    if (-not (Test-Path -LiteralPath $root)) { throw "Missing Step 14R artifact root: $root" }
    Get-ChildItem -LiteralPath $root -File -Recurse -Filter $spec.Filter | Sort-Object FullName | ForEach-Object {
        $paths.Add($_.FullName.Substring($RepoRoot.Length + 1).Replace('\','/'))
    }
}

$paths = @($paths | Sort-Object -Unique)
$rows = [System.Collections.Generic.List[string]]::new()
$index = 1
foreach ($relative in $paths) {
    $absolute = Join-Path $RepoRoot ($relative.Replace('/','\'))
    if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) { throw "Missing Step 14R artifact: $relative" }
    $hash = (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash
    $type = if ($relative -match '\.(mq5|mqh|py|ps1)$') { 'source' } elseif ($relative -match '\.(set|ini)$') { 'source/config' } elseif ($relative -like 'docs/*') { 'document' } else { 'generated evidence' }
    $sourceGenerated = if ($type -eq 'generated evidence') { 'generated evidence' } else { 'source' }
    $id = 'TS-S14R-{0:D3}' -f $index
    $rows.Add("| $id | 14R | ``$relative`` | $type | pre-Step-15 remediation and March replay | $sourceGenerated | ``$hash`` | yes | explicit promotion review | COMPLETE | no automatic long OOS; exact paths authoritative | SELF |")
    ++$index
}

$existingRows = @(($text -split "\r?\n") | Where-Object { $_ -match '^\| TS-' }).Count
$existingPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($match in [regex]::Matches($text, '(?m)^\| TS-[^|]+\|[^|]+\| `([^`]+)` \|')) { [void]$existingPaths.Add($match.Groups[1].Value) }
foreach ($relative in $paths) { [void]$existingPaths.Add($relative) }
$projectedRows = $existingRows + $rows.Count

$section = @"

## Step 14R pre-Step-15 remediation artifacts

Step 14R appends $($rows.Count) current source, test, validator, order-observation,
compile and March replay rows. The projected rollup is $projectedRows artifact
rows and $($existingPaths.Count) unique paths. Artifact IDs are generated once
within this section and were checked for duplicates. `owning_commit=SELF` means
the first Step 14R evidence commit containing the path. The implementation
checkpoint is `d454622786795a85c21e16a4d154440eef80b48f`; no automatic Step 15,
long OOS or optimization is authorized.

| artifact ID | step | artifact relative path | type | purpose | source/generated | SHA-256 | commit | next Step | status | note | owning_commit |
|---|---:|---|---|---|---|---|---|---|---|---|---|
$($rows -join "`n")
"@

[System.IO.File]::WriteAllText($manifestPath, $text.TrimEnd() + "`r`n" + $section, $utf8NoBom)
Write-Host "Step 14R manifest rows appended: $($rows.Count); projected total: $projectedRows; unique paths: $($existingPaths.Count)"
