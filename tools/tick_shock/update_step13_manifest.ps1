param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$manifestPath = Join-Path $RepoRoot "docs\research\tick_shock\00_artifact_manifest.md"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$text = [System.IO.File]::ReadAllText($manifestPath, $utf8NoBom)
$text = [regex]::Replace($text, '(?s)\r?\n## Step 13 Strategy Tester order observation.*$', '')
$text = [regex]::Replace($text, '(?m)^- status: `[^`]+`\r?$', '- status: `STEP13_ORDER_OBSERVATION_COMPLETE`')
$text = [regex]::Replace($text, '(?m)^- manifest_revision: `[^`]+`\r?$', '- manifest_revision: `13`')
$text = [regex]::Replace($text, '(?m)^- covered_steps: `[^`]+`\r?$', '- covered_steps: `01-13`')
$text = [regex]::Replace($text, '(?m)^- last_audited_commit: `[^`]+`\r?$', '- last_audited_commit: `21fe3312b1a0ca92e50fc8c03ca174df7e771341`')
$text = [regex]::Replace($text, '(?m)^- last_updated_at: `[^`]+`\r?$', '- last_updated_at: `2026-08-24T19:30:00+09:00`')

$paths = New-Object System.Collections.Generic.List[string]
$paths.Add('mql/Experts/tests/ExpectedValue_TickShock_OrderReachabilityHarness.mq5')
$paths.Add('docs/research/tick_shock/13_order_observation.md')
$paths.Add('docs/devlog/2026-08-24-tickshock-step13-order-observation.md')
$paths.Add('tools/tick_shock/build_step13_order_observation.py')
$paths.Add('tools/tick_shock/build_step13_hashes.py')
$paths.Add('tools/tick_shock/update_step13_manifest.ps1')

Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'reports\tests\tick_shock\step13_order_observation') -File |
    Sort-Object Name |
    ForEach-Object { $paths.Add((Resolve-Path -LiteralPath $_.FullName -Relative).TrimStart('.','\').Replace('\','/')) }
Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'reports\compile\tick_shock') -Filter 'step13_*.log' -File |
    Sort-Object Name |
    ForEach-Object { $paths.Add((Resolve-Path -LiteralPath $_.FullName -Relative).TrimStart('.','\').Replace('\','/')) }

$paths = @($paths | Select-Object -Unique)
$rows = New-Object System.Collections.Generic.List[string]
$index = 1
foreach ($relative in $paths) {
    $absolute = Join-Path $RepoRoot ($relative.Replace('/','\'))
    if (-not (Test-Path -LiteralPath $absolute)) {
        throw "Missing Step 13 artifact: $relative"
    }
    $hash = (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash
    $type = if ($relative -like 'mql/*' -or $relative -like 'tools/*' -or $relative -like '*.set' -or $relative -like '*.ini') { 'source/config' } elseif ($relative -like 'docs/*') { 'document' } else { 'generated evidence' }
    $sourceGenerated = if ($type -eq 'generated evidence') { 'generated evidence' } else { 'source' }
    $id = 'TS-S13-{0:D3}' -f $index
    $rows.Add("| $id | 13 | ``$relative`` | $type | Strategy Tester order lifecycle and commission observation | $sourceGenerated | ``$hash`` | yes | Step 14 | COMPLETE | tester-only; unobserved cases remain explicit | SELF |")
    ++$index
}

$section = @"

## Step 13 Strategy Tester order observation

The order harness alone submitted simulated Strategy Tester orders. The research
EA remains order-free. `owning_commit=SELF` identifies the Step 13 commit. Zero
tester commission is recorded as observed tester data, not live-broker evidence.

| artifact ID | step | artifact relative path | type | purpose | source/generated | SHA-256 | commit | next Step | status | note | owning_commit |
|---|---:|---|---|---|---|---|---|---|---|---|---|
$($rows -join "`n")
"@

[System.IO.File]::WriteAllText($manifestPath, $text.TrimEnd() + "`r`n" + $section, $utf8NoBom)
Write-Host "Step 13 manifest rows appended: $($rows.Count)"
