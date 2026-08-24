$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$manifestPath = Join-Path $repoRoot "docs\research\tick_shock\00_artifact_manifest.md"
$lines = [System.Collections.Generic.List[string]](Get-Content -LiteralPath $manifestPath -Encoding UTF8)

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -eq '- status: `STEP10_TESTABILITY_REFACTOR_ROLLUP`') { $lines[$i] = '- status: `STEP11_PRE_FIX_RED_ROLLUP`' }
    elseif ($lines[$i] -eq '- manifest_revision: `10`') { $lines[$i] = '- manifest_revision: `11`' }
    elseif ($lines[$i] -eq '- covered_steps: `01-10`') { $lines[$i] = '- covered_steps: `01-11`' }
    elseif ($lines[$i] -like '- last_updated_at:*') { $lines[$i] = '- last_updated_at: `2026-08-24T12:00:00+09:00`' }
}

$paths = [System.Collections.Generic.List[string]]::new()
foreach ($path in @(
    "docs/research/tick_shock/03_test_specification.md",
    "docs/research/tick_shock/03_requirements_traceability.md",
    "docs/research/tick_shock/11_pre_fix_test_additions.md",
    "docs/research/tick_shock/11_test_oracle_addendum.md",
    "mql/Experts/tests/TickShockStep5TestSupport.mqh",
    "mql/Experts/tests/ExpectedValue_TickShock_IntegrityRegressionHarness.mq5",
    "tests/tick_shock/spec/test_cases.csv",
    "tests/tick_shock/python/conftest.py",
    "tests/tick_shock/python/test_fixture_integrity.py",
    "tools/tick_shock/run_all_tests.ps1",
    "tools/tick_shock/run_mql_harnesses.ps1",
    "tools/tick_shock/run_python_tests.py",
    "tools/tick_shock/generate_step11_fixtures.ps1",
    "tools/tick_shock/update_step11_manifest.ps1",
    "reports/tests/tick_shock/step11_pre_fix_results.csv",
    "reports/tests/tick_shock/step11_pre_fix_red_report.md"
)) { $paths.Add($path) }
$step11IdPattern = '^TS-(CONFIG-00[1-6]|COMM-00[2-4]|CSV-00[3-6]|CAP-00[1-3]|CURSOR-001|STATUS-00[1-2]|DIRECTION-001|ORDER-00[4-7]|WATERMARK-00[1-2])_'
foreach ($file in Get-ChildItem (Join-Path $repoRoot "tests\tick_shock\fixtures") -File | Where-Object Name -Match $step11IdPattern) {
    $paths.Add($file.FullName.Substring($repoRoot.Length + 1).Replace('\','/'))
}
foreach ($file in Get-ChildItem (Join-Path $repoRoot "tests\tick_shock\expected") -File | Where-Object Name -Match $step11IdPattern) {
    $paths.Add($file.FullName.Substring($repoRoot.Length + 1).Replace('\','/'))
}
foreach ($file in Get-ChildItem (Join-Path $repoRoot "reports\tests\tick_shock\step11_raw") -File) {
    $paths.Add($file.FullName.Substring($repoRoot.Length + 1).Replace('\','/'))
}
foreach ($file in Get-ChildItem (Join-Path $repoRoot "reports\tests\tick_shock\configs") -File -Filter 'step11_*') {
    $paths.Add($file.FullName.Substring($repoRoot.Length + 1).Replace('\','/'))
}
foreach ($file in Get-ChildItem (Join-Path $repoRoot "reports\tests\tick_shock\tester") -File -Filter 'step11_*') {
    $paths.Add($file.FullName.Substring($repoRoot.Length + 1).Replace('\','/'))
}
foreach ($file in Get-ChildItem (Join-Path $repoRoot "reports\compile\tick_shock") -File -Filter 'step11_*') {
    $paths.Add($file.FullName.Substring($repoRoot.Length + 1).Replace('\','/'))
}

$existingPaths = @{}
$sequence = 0
foreach ($line in $lines) {
    if ($line -match '^\| TS-S11-(\d+) \|') { $sequence = [Math]::Max($sequence, [int]$Matches[1]) }
    if ($line -match '^\| TS-S11-\d+ \| 11 \| `([^`]+)` \|') { $existingPaths[$Matches[1]] = $true }
}
foreach ($relative in $paths | Sort-Object -Unique) {
    if ($existingPaths.ContainsKey($relative)) { continue }
    $absolute = Join-Path $repoRoot $relative
    if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) { throw "Manifest artifact missing: $relative" }
    $sequence++
    $artifactId = "TS-S11-{0:D3}" -f $sequence
    if ($lines -match "\| $artifactId \|") { throw "Duplicate artifact ID: $artifactId" }
    $sha = (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash
    $kind = if ($relative -match 'fixture|expected|test_cases') { "test vector" } elseif ($relative -match 'raw|results') { "test evidence" } elseif ($relative -match '\.(mq5|mqh|py|ps1)$') { "test source" } else { "document" }
    $sourceClass = if ($kind -eq "test evidence") { "generated evidence" } else { "source" }
    $lines.Add("| $artifactId | 11 | ``$relative`` | $kind | Step 11 pre-fix executable evidence | $sourceClass | ``$sha`` | yes | Step 12 | COMPLETE | immutable Step 12 input | SELF |")
}
[System.IO.File]::WriteAllLines($manifestPath, $lines, [System.Text.UTF8Encoding]::new($false))
Write-Host "Step 11 manifest sequence now $sequence."
