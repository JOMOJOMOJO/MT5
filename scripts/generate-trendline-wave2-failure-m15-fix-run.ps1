param(
    [string]$RunRoot = "reports\backtest\runs\20260816_trendline_wave2_failure_execution_shadow",
    [int]$Model = 4
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$root = if ([IO.Path]::IsPathRooted($RunRoot)) { $RunRoot } else { Join-Path $repoRoot $RunRoot }
$template = Join-Path $repoRoot "reports\backtest\runs\20260815_trendline_wave2_failure\new_bucket_only_2024\preset.set"
$runId = "execution_shadow_2024"
$runDir = Join-Path $root $runId

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

if (-not (Test-Path -LiteralPath $template)) { throw "Template preset not found: $template" }
New-Item -ItemType Directory -Path $runDir -Force | Out-Null

$lines = @(Get-Content -LiteralPath $template)
$values = [ordered]@{
    InpBucketMode = "1"
    InpMagicNumber = "202608169014"
    InpTW2FMagicNumber = "202608169015"
    InpRunId = $runId
    InpLogFolder = "trendline_wave2_failure_${runId}_legacy"
    InpTW2FLogFolder = "trendline_wave2_failure_${runId}"
}
foreach ($entry in $values.GetEnumerator()) {
    $lines = @(Set-PresetValue -Lines $lines -Key $entry.Key -Value $entry.Value)
}
$presetPath = Join-Path $runDir "preset.set"
$lines | Set-Content -LiteralPath $presetPath -Encoding ASCII

$relativeRunRoot = $root.Substring($repoRoot.Length + 1)
$iniPath = Join-Path $runDir "tester.ini"
$ini = @(
    "; M15 state-machine fix verification; strategy parameters copied from the original 2024 run.",
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
    "PresetSource=${relativeRunRoot}\${runId}\preset.set",
    "PresetName=ExpectedValue_MultiCurrency_FractalWave2TransitionTrader_tw2f_${runId}.set",
    "Symbol=USDJPY",
    "Period=M15",
    "Model=$Model",
    "ExecutionMode=0",
    "Optimization=0",
    "OptimizationCriterion=6",
    "FromDate=2024.01.01",
    "ToDate=2024.12.31",
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
    "Report=MQL5\Experts\dev\${relativeRunRoot}\${runId}\report.html"
)
$ini | Set-Content -LiteralPath $iniPath -Encoding ASCII

[pscustomobject]@{
    sequence = 1
    run_id = $runId
    year = "2024"
    mode = "new_bucket_only"
    bucket_mode = 1
    model = $Model
    from_date = "2024.01.01"
    to_date = "2024.12.31"
    preset = $presetPath.Substring($repoRoot.Length + 1)
    tester_ini = $iniPath.Substring($repoRoot.Length + 1)
    log_folder = "trendline_wave2_failure_${runId}"
    legacy_log_folder = "trendline_wave2_failure_${runId}_legacy"
} | Export-Csv -LiteralPath (Join-Path $root "run_matrix.csv") -NoTypeInformation -Encoding UTF8

$lockedKeys = @(
    "InpContextTF", "InpSetupTF", "InpEntryTF", "InpATRPeriod",
    "InpImpulseMinATR", "InpImpulsePercentile", "InpMinimumDirectionalEfficiency",
    "InpImpulseCloseLocation", "InpStructureBreakBufferATR", "InpH1RequiredLowerHighs",
    "InpH1RequiredLowerLows", "InpH1MinimumTrendATR", "InpH1MinimumTrendBars",
    "InpTrendlineMinBars", "InpTrendlineMinHeightATR", "InpTrendlineBreakBufferATR",
    "InpWaveInvalidationBufferATR", "InpEqualBottomToleranceATR", "InpHigherLowMaxATR",
    "InpFalseBreakMaxATR", "InpPatternMinBars", "InpPatternMaxBars",
    "InpMinimumPatternHeightATR", "InpEntryBufferATR", "InpRequireM15MASlope",
    "InpTW2FStopMode", "InpSLSpreadMultiplier", "InpSLBufferATR", "InpTakeProfitR",
    "InpMinimumPlannedRR", "InpLotMode", "InpRiskBase", "InpRiskPercent",
    "InpTW2FMaxTotalOpenRiskPercent", "InpMaxRiskPerCurrencyDirectionPercent"
)
$templateMap = @{}
$newMap = @{}
foreach ($line in Get-Content -LiteralPath $template) {
    if ($line -match "^([^=]+)=(.*)$") { $templateMap[$Matches[1]] = $Matches[2] }
}
foreach ($line in Get-Content -LiteralPath $presetPath) {
    if ($line -match "^([^=]+)=(.*)$") { $newMap[$Matches[1]] = $Matches[2] }
}
$differences = @($lockedKeys | Where-Object { $templateMap[$_] -ne $newMap[$_] })
if ($differences.Count -gt 0) { throw "Locked strategy parameters changed: $($differences -join ', ')" }

[ordered]@{
    generated_at = (Get-Date).ToString("o")
    source_preset = $template.Substring($repoRoot.Length + 1)
    tester_model = $Model
    period = "2024.01.01..2024.12.31"
    locked_strategy_parameter_differences = $differences
    source_sha256 = (Get-FileHash -LiteralPath (Join-Path $repoRoot "mql\Experts\ExpectedValue_MultiCurrency_FractalWave2TransitionTrader.mq5") -Algorithm SHA256).Hash
    include_sha256 = (Get-FileHash -LiteralPath (Join-Path $repoRoot "mql\Include\TrendlineWave2Failure.mqh") -Algorithm SHA256).Hash
    preset_sha256 = (Get-FileHash -LiteralPath $presetPath -Algorithm SHA256).Hash
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root "run_lock.json") -Encoding UTF8

Write-Host "Generated M15 state-machine verification run: $runDir"
