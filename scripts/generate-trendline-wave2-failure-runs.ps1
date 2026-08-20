param(
    [string]$RunRoot = "reports\backtest\runs\20260815_trendline_wave2_failure",
    [int]$Model = 4
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$root = if ([IO.Path]::IsPathRooted($RunRoot)) { $RunRoot } else { Join-Path $repoRoot $RunRoot }
$template = Join-Path $root "smoke_2024q1\preset.set"
if (-not (Test-Path -LiteralPath $template)) {
    throw "Template preset not found: $template"
}

function Set-PresetValue {
    param([string[]]$Lines, [string]$Key, [string]$Value)
    $found = $false
    $updated = foreach ($line in $Lines) {
        if ($line -match "^$([regex]::Escape($Key))=") {
            $found = $true
            "$Key=$Value"
        } else {
            $line
        }
    }
    if (-not $found) { $updated += "$Key=$Value" }
    return @($updated)
}

$periods = @(
    [pscustomobject]@{ year = "2024"; from = "2024.01.01"; to = "2024.12.31" },
    [pscustomobject]@{ year = "2025"; from = "2025.01.01"; to = "2025.12.31" },
    [pscustomobject]@{ year = "2026"; from = "2026.01.01"; to = "2026.08.14" }
)
$modes = @(
    [pscustomobject]@{ name = "baseline"; bucket = "0" },
    [pscustomobject]@{ name = "new_bucket_only"; bucket = "1" },
    [pscustomobject]@{ name = "combined"; bucket = "2" }
)

$matrix = @()
$sequence = 0
foreach ($period in $periods) {
    foreach ($mode in $modes) {
        $sequence++
        $runId = "$($mode.name)_$($period.year)"
        $runDir = Join-Path $root $runId
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $presetPath = Join-Path $runDir "preset.set"
        $iniPath = Join-Path $runDir "tester.ini"
        $legacyMagic = 202608151000 + $sequence * 2
        $newMagic = $legacyMagic + 1
        $lines = @(Get-Content -LiteralPath $template)
        $values = [ordered]@{
            InpBucketMode = $mode.bucket
            InpMagicNumber = [string]$legacyMagic
            InpTW2FMagicNumber = [string]$newMagic
            InpRunId = $runId
            InpLogFolder = "trendline_wave2_failure_${runId}_legacy"
            InpTW2FLogFolder = "trendline_wave2_failure_${runId}"
        }
        foreach ($entry in $values.GetEnumerator()) {
            $lines = @(Set-PresetValue -Lines $lines -Key $entry.Key -Value $entry.Value)
        }
        Set-Content -LiteralPath $presetPath -Value $lines -Encoding ASCII

        $expertPreset = "ExpectedValue_MultiCurrency_FractalWave2TransitionTrader_tw2f_${runId}.set"
        $report = "MQL5\Experts\dev\reports\backtest\runs\20260815_trendline_wave2_failure\${runId}\report.html"
        $ini = @(
            "; Locked TRENDLINE_WAVE2_FAILURE annual comparison.",
            "",
            "[Experts]",
            "Enabled=0",
            "AllowLiveTrading=0",
            "AllowDllImport=0",
            "Account=0",
            "Profile=0",
            "",
            "[Tester]",
            "Expert=dev\mql\Experts\ExpectedValue_MultiCurrency_FractalWave2TransitionTrader.ex5",
            "PresetSource=reports\backtest\runs\20260815_trendline_wave2_failure\${runId}\preset.set",
            "PresetName=$expertPreset",
            "Symbol=USDJPY",
            "Period=M15",
            "Model=$Model",
            "ExecutionMode=0",
            "Optimization=0",
            "OptimizationCriterion=6",
            "FromDate=$($period.from)",
            "ToDate=$($period.to)",
            "ForwardMode=0",
            "Deposit=10000",
            "Currency=USD",
            "Leverage=1:100",
            "UseLocal=1",
            "UseRemote=0",
            "UseCloud=0",
            "Visual=0",
            "ReplaceReport=1",
            "ShutdownTerminal=1",
            "Report=$report"
        )
        Set-Content -LiteralPath $iniPath -Value $ini -Encoding ASCII
        $matrix += [pscustomobject]@{
            sequence = $sequence
            run_id = $runId
            year = $period.year
            mode = $mode.name
            bucket_mode = $mode.bucket
            model = $Model
            from_date = $period.from
            to_date = $period.to
            preset = $presetPath.Substring($repoRoot.Length + 1)
            tester_ini = $iniPath.Substring($repoRoot.Length + 1)
            log_folder = "trendline_wave2_failure_${runId}"
            legacy_log_folder = "trendline_wave2_failure_${runId}_legacy"
        }
    }
}
$matrix | Export-Csv -LiteralPath (Join-Path $root "run_matrix.csv") -NoTypeInformation -Encoding UTF8

$source = Join-Path $repoRoot "mql\Experts\ExpectedValue_MultiCurrency_FractalWave2TransitionTrader.mq5"
$include = Join-Path $repoRoot "mql\Include\TrendlineWave2Failure.mqh"
$lock = [ordered]@{
    locked_at = (Get-Date).ToString("o")
    oos_from = "2026.01.01"
    oos_to_requested = "2026.08.14"
    tester_model = $Model
    source_sha256 = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    include_sha256 = (Get-FileHash -LiteralPath $include -Algorithm SHA256).Hash
    preset_sha256 = (Get-FileHash -LiteralPath (Join-Path $root "new_bucket_only_2024\preset.set") -Algorithm SHA256).Hash
    note = "Parameters were locked before any 2026 run. Run-specific IDs, magic numbers and log folders differ; strategy parameters do not."
}
$lock | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root "oos_lock.json") -Encoding UTF8
Write-Host "Generated annual run matrix: $(Join-Path $root 'run_matrix.csv')"
Write-Host "Wrote OOS lock: $(Join-Path $root 'oos_lock.json')"
