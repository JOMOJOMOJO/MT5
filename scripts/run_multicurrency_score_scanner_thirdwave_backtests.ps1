param(
    [string]$TerminalPath = "C:\Users\windows\AppData\Local\CodexMT5BucketLab\terminal64.exe",
    [int]$TimeoutSeconds = 14400,
    [string[]]$RunIds = @("A", "B", "C"),
    [string]$SeriesName = "2025_thirdwave",
    [string]$FromDate = "2025.01.01",
    [string]$ToDate = "2025.12.31",
    [int]$BaseMagicNumber = 2026060310,
    [ValidateSet("Original", "RegimeComparison")]
    [string]$ScenarioSet = "Original"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$backtestDir = Join-Path $repoRoot "reports\backtest"
$presetDir = Join-Path $repoRoot "reports\presets"
$portableRoot = Split-Path -Parent (Resolve-Path $TerminalPath).Path
$resolvedTerminalPath = (Resolve-Path $TerminalPath).Path
$commonFilesRoot = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$resolvedCommonFilesRoot = (Resolve-Path $commonFilesRoot).Path
$templatePreset = Join-Path $presetDir "ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_A_both_5m.set"
$seriesPrefix = "ExpectedValue_MultiCurrency_ScoreScanner_$SeriesName"
$elapsedPath = Join-Path $backtestDir "${seriesPrefix}_elapsed.csv"
$requestedRunIds = @(
    foreach ($runId in $RunIds) {
        foreach ($part in ($runId -split ",")) {
            $trimmed = $part.Trim()
            if ($trimmed) {
                $trimmed
            }
        }
    }
)

function New-Run {
    param(
        [string]$Id,
        [string]$Name,
        [int]$StrategyMode,
        [int]$DirectionMode,
        [int]$MagicNumber,
        [string]$Scenario
    )

    $prefix = "${seriesPrefix}_$Name"
    [pscustomobject]@{
        Id = $Id
        Name = $Name
        Prefix = $prefix
        StrategyMode = $StrategyMode
        DirectionMode = $DirectionMode
        MagicNumber = $MagicNumber
        Scenario = $Scenario
        IniPath = Join-Path $backtestDir "$prefix.ini"
        PresetPath = Join-Path $presetDir "$prefix.set"
        PresetName = "$prefix.set"
        ReportStem = "${prefix}_report"
        LogFolder = "multicurrency_score_scanner_${SeriesName}_$Name"
    }
}

if ($ScenarioSet -eq "RegimeComparison") {
    $runs = @(
        New-Run -Id "A" -Name "A_original_both" -StrategyMode 1 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 1) -Scenario "ThirdWave_original_BOTH"
        New-Run -Id "B" -Name "B_regime_both" -StrategyMode 2 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 2) -Scenario "ThirdWave_regime_BOTH"
        New-Run -Id "C" -Name "C_regime_long_only" -StrategyMode 2 -DirectionMode 1 -MagicNumber ($BaseMagicNumber + 3) -Scenario "ThirdWave_regime_LONG_ONLY"
        New-Run -Id "D" -Name "D_regime_short_only" -StrategyMode 2 -DirectionMode 2 -MagicNumber ($BaseMagicNumber + 4) -Scenario "ThirdWave_regime_SHORT_ONLY"
    )
} else {
    $runs = @(
        New-Run -Id "A" -Name "A_both" -StrategyMode 1 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 1) -Scenario "ThirdWave_BOTH"
        New-Run -Id "B" -Name "B_long_only" -StrategyMode 1 -DirectionMode 1 -MagicNumber ($BaseMagicNumber + 2) -Scenario "ThirdWave_LONG_ONLY"
        New-Run -Id "C" -Name "C_short_only" -StrategyMode 1 -DirectionMode 2 -MagicNumber ($BaseMagicNumber + 3) -Scenario "ThirdWave_SHORT_ONLY"
    )
}

function Sync-EaToPortable {
    $targetDir = Join-Path $portableRoot "MQL5\Experts\dev\mql\Experts"
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot "mql\Experts\ExpectedValue_MultiCurrency_ScoreScanner.mq5") -Destination $targetDir -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot "mql\Experts\ExpectedValue_MultiCurrency_ScoreScanner.ex5") -Destination $targetDir -Force
}

function Stop-MatchingPortableTerminal {
    $running = @(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {
        try {
            $_.Path -eq $resolvedTerminalPath
        } catch {
            $false
        }
    })

    foreach ($process in $running) {
        Stop-Process -Id $process.Id -Force
        try {
            Wait-Process -Id $process.Id -Timeout 15 -ErrorAction SilentlyContinue
        } catch {
        }
    }
}

function Write-ThirdWavePreset {
    param([object]$Run)

    $lines = Get-Content -Path $templatePreset
    $out = New-Object System.Collections.Generic.List[string]
    $insertedStrategyMode = $false
    foreach ($line in $lines) {
        if ($line -match '^InpResearchStrategyMode=') {
            $out.Add("InpResearchStrategyMode=$($Run.StrategyMode)||$($Run.StrategyMode)||0||2||N")
            $insertedStrategyMode = $true
            continue
        }
        if ($line -match '^InpTradeDirectionMode=') {
            $out.Add("InpTradeDirectionMode=$($Run.DirectionMode)||$($Run.DirectionMode)||0||2||N")
            continue
        }
        if ($line -match '^InpSymbolResearchMode=') {
            $out.Add("InpSymbolResearchMode=0||0||0||2||N")
            continue
        }
        if ($line -match '^InpDisableUsdJpyShort=') {
            $out.Add("InpDisableUsdJpyShort=false||false||0||true||N")
            continue
        }
        if ($line -match '^InpUseDowFractalStructureFilter=') {
            $out.Add("InpUseDowFractalStructureFilter=false||false||0||true||N")
            continue
        }
        if ($line -match '^InpMagicNumber=') {
            $out.Add("InpMagicNumber=$($Run.MagicNumber)||$($Run.MagicNumber)||1||999999999||N")
            continue
        }
        if ($line -match '^InpLogFolder=') {
            $out.Add("InpLogFolder=$($Run.LogFolder)")
            continue
        }
        $out.Add($line)
        if (-not $insertedStrategyMode -and $line -match '^InpExecutionTF=') {
            $out.Add("InpResearchStrategyMode=$($Run.StrategyMode)||$($Run.StrategyMode)||0||2||N")
            $insertedStrategyMode = $true
        }
    }
    Set-Content -Path $Run.PresetPath -Value $out -Encoding ASCII
}

function Write-ThirdWaveIni {
    param([object]$Run)

    $lines = @(
        "; MT5 Strategy Tester config for DowFractal ThirdWave diagnostics.",
        "; $($Run.Id): ThirdWave research branch, $SeriesName, hard stops disabled.",
        "",
        "[Experts]",
        "Enabled=1",
        "AllowLiveTrading=1",
        "AllowDllImport=0",
        "Account=0",
        "Profile=0",
        "",
        "[Tester]",
        "Expert=dev\mql\Experts\ExpectedValue_MultiCurrency_ScoreScanner.ex5",
        "PresetSource=reports\presets\$($Run.PresetName)",
        "PresetName=$($Run.PresetName)",
        "Symbol=USDJPY",
        "Period=M5",
        "Model=4",
        "ExecutionMode=0",
        "Optimization=0",
        "OptimizationCriterion=6",
        "FromDate=$FromDate",
        "ToDate=$ToDate",
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
        "Report=$($Run.ReportStem).html"
    )
    Set-Content -Path $Run.IniPath -Value $lines -Encoding ASCII
}

function Ensure-Inputs {
    foreach ($run in $runs) {
        Write-ThirdWavePreset -Run $run
        Write-ThirdWaveIni -Run $run
    }
}

function Copy-PresetToPortable {
    param([object]$Run)

    $targets = @(
        (Join-Path $portableRoot "MQL5\Profiles\Tester"),
        (Join-Path $portableRoot "Profiles\Tester")
    ) | Select-Object -Unique

    foreach ($target in $targets) {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        Copy-Item -LiteralPath $Run.PresetPath -Destination (Join-Path $target $Run.PresetName) -Force
    }
}

function Clear-RunLogFolder {
    param([object]$Run)

    $target = Join-Path $resolvedCommonFilesRoot $Run.LogFolder
    if (-not (Test-Path $target)) {
        return
    }

    $resolvedTarget = (Resolve-Path $target).Path
    if (-not $resolvedTarget.StartsWith($resolvedCommonFilesRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to delete log folder outside Common Files: $resolvedTarget"
    }
    if ([System.IO.Path]::GetFileName($resolvedTarget) -ne $Run.LogFolder) {
        throw "Refusing to delete unexpected log folder: $resolvedTarget"
    }

    Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
}

function New-PortableConfig {
    param([object]$Run)

    $lines = Get-Content -Path $Run.IniPath
    $out = New-Object System.Collections.Generic.List[string]
    $hasExpertParameters = $false
    foreach ($line in $lines) {
        if ($line -match '^\s*PresetSource=' -or $line -match '^\s*PresetName=') {
            continue
        }
        if ($line -match '^\s*ExpertParameters=') {
            $out.Add("ExpertParameters=$($Run.PresetName)")
            $hasExpertParameters = $true
            continue
        }
        if ($line -match '^\s*Report=') {
            $out.Add("Report=$($Run.ReportStem)")
            continue
        }
        $out.Add($line)
    }
    if (-not $hasExpertParameters) {
        $testerIndex = $out.IndexOf("[Tester]")
        if ($testerIndex -ge 0) {
            $out.Insert($testerIndex + 1, "ExpertParameters=$($Run.PresetName)")
        } else {
            $out.Add("ExpertParameters=$($Run.PresetName)")
        }
    }

    $configPath = Join-Path ([System.IO.Path]::GetTempPath()) "$($Run.Prefix).portable.ini"
    Set-Content -Path $configPath -Value $out -Encoding ASCII
    return $configPath
}

function Find-ReportPath {
    param([object]$Run)

    $candidates = @(
        (Join-Path $portableRoot "$($Run.ReportStem).htm"),
        (Join-Path $portableRoot "$($Run.ReportStem).html")
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }
    return $null
}

function Clear-PortableReportFiles {
    param([object]$Run)

    Get-ChildItem -Path $portableRoot -File -Filter "$($Run.ReportStem)*" -ErrorAction SilentlyContinue |
        Remove-Item -Force
}

function Copy-ReportsToRepo {
    param([object]$Run)

    $reportPath = Find-ReportPath -Run $Run
    if (-not $reportPath) {
        throw "Report file was not found for $($Run.Id) under $portableRoot"
    }

    Copy-Item -LiteralPath $reportPath -Destination (Join-Path $backtestDir "$($Run.ReportStem).html") -Force
    foreach ($suffix in @(".png", "-hst.png", "-mfemae.png", "-holding.png")) {
        $source = Join-Path $portableRoot "$($Run.ReportStem)$suffix"
        if (Test-Path $source) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $backtestDir "$($Run.ReportStem)$suffix") -Force
        }
    }
}

function Join-CsvFiles {
    param(
        [System.IO.FileInfo[]]$Files,
        [string]$OutputPath,
        [string[]]$EmptyHeader
    )

    if (Test-Path $OutputPath) {
        Remove-Item -LiteralPath $OutputPath -Force
    }

    if (-not $Files -or $Files.Count -eq 0) {
        if ($EmptyHeader -and $EmptyHeader.Count -gt 0) {
            Set-Content -Path $OutputPath -Value ($EmptyHeader -join ",") -Encoding UTF8
        }
        return
    }

    $first = $true
    foreach ($file in ($Files | Sort-Object Name)) {
        $lines = Get-Content -Path $file.FullName
        if ($lines.Count -eq 0) {
            continue
        }
        if ($first) {
            Add-Content -Path $OutputPath -Value $lines -Encoding UTF8
            $first = $false
        } else {
            Add-Content -Path $OutputPath -Value ($lines | Select-Object -Skip 1) -Encoding UTF8
        }
    }
}

function Copy-LogsToRepo {
    param([object]$Run)

    $logDir = Join-Path $resolvedCommonFilesRoot $Run.LogFolder
    if (-not (Test-Path $logDir)) {
        throw "Common Files log folder was not found: $logDir"
    }

    $scanFiles = @(Get-ChildItem -Path $logDir -File -Filter "multicurrency_score_scan_*.csv")
    $signalFiles = @(Get-ChildItem -Path $logDir -File -Filter "thirdwave_signal_diagnostics_*.csv")
    $tradeFiles = @(Get-ChildItem -Path $logDir -File -Filter "thirdwave_trade_diagnostics_*.csv")
    $summaryFiles = @(Get-ChildItem -Path $logDir -File -Filter "thirdwave_summary_*.csv")

    Join-CsvFiles -Files $scanFiles -OutputPath (Join-Path $backtestDir "$($Run.Prefix)_scan_diagnostics.csv") -EmptyHeader @("time", "event", "last_scan_bar_time", "scan_elapsed_ms", "reason")
    Join-CsvFiles -Files $signalFiles -OutputPath (Join-Path $backtestDir "$($Run.Prefix)_thirdwave_signal_diagnostics.csv") -EmptyHeader @("time", "symbol", "direction", "higher_tf_trend", "mid_tf_pullback_status", "lower_tf_reversal_status", "regime", "regime_reason", "higher_tf_swing_state", "ema_slope", "trend_strength", "volatility_state", "entry_allowed_by_regime", "blocked_by_regime_reason", "lower_reversal_quality", "pullback_depth_atr", "sl_atr", "setup_pass", "entry_pass", "final_entry_pass", "skip_reason", "structure_stage_fail_reason", "execution_block_reason", "higher_tf_trend_pass", "mid_tf_pullback_pass", "lower_tf_reversal_pass", "structure_sl_pass", "rr_pass", "spread_atr", "max_spread_atr", "spread_guard_pass", "spread_guard_blocked", "spread_points", "atr_value", "entry_price", "sl", "tp", "risk_r", "rr", "swing_high", "swing_low", "structure_sl_source", "strategy_name")
    Join-CsvFiles -Files $tradeFiles -OutputPath (Join-Path $backtestDir "$($Run.Prefix)_thirdwave_trade_diagnostics.csv") -EmptyHeader @("time", "symbol", "direction", "event", "regime", "regime_reason", "higher_tf_swing_state", "ema_slope", "trend_strength", "volatility_state", "entry_allowed_by_regime", "blocked_by_regime_reason", "lower_reversal_quality", "pullback_depth_atr", "sl_atr", "order_retcode", "order_comment", "entry_price", "sl", "tp", "volume", "risk_r", "rr", "skip_reason", "structure_stage_fail_reason", "execution_block_reason", "spread_atr", "max_spread_atr", "spread_guard_pass", "spread_guard_blocked", "spread_points", "atr_value", "strategy_name")
    Join-CsvFiles -Files $summaryFiles -OutputPath (Join-Path $backtestDir "$($Run.Prefix)_thirdwave_summary.csv") -EmptyHeader @("time", "strategy_name", "evaluations", "long_evaluations", "short_evaluations", "setup_pass", "entry_pass", "orders_sent", "orders_failed", "higher_tf_trend_pass", "mid_tf_pullback_pass", "lower_tf_reversal_pass", "structure_sl_pass", "rr_pass", "spread_guard_pass", "spread_guard_blocked", "final_entry_pass", "regime_trend_up", "regime_trend_down", "regime_range", "regime_transition", "regime_exhaustion", "regime_unknown", "regime_allowed", "regime_blocked", "regime_block_long_requires_trend_up", "regime_block_short_requires_trend_down", "long_higher_tf_trend_pass", "long_mid_tf_pullback_pass", "long_lower_tf_reversal_pass", "long_structure_sl_pass", "long_rr_pass", "long_spread_guard_pass", "long_spread_guard_blocked", "long_final_entry_pass", "short_higher_tf_trend_pass", "short_mid_tf_pullback_pass", "short_lower_tf_reversal_pass", "short_structure_sl_pass", "short_rr_pass", "short_spread_guard_pass", "short_spread_guard_blocked", "short_final_entry_pass", "no_higher_tf_trend", "trend_broken", "no_mid_pullback", "pullback_too_shallow", "pullback_too_deep", "no_lower_reversal", "lower_reversal_quality_low", "sl_too_close", "sl_too_wide", "rr_too_low", "existing_position", "market_closed", "spread_guard", "data_unavailable", "atr_unavailable", "research_excluded", "regime_requires_trend_up", "regime_requires_trend_down", "unknown", "execution_spread_guard", "execution_trading_disabled", "execution_no_entry_signal", "execution_position_limit", "execution_risk_stop", "execution_risk_limit", "execution_invalid", "execution_order_failed", "execution_unknown", "top_structure_stage_fail_reason", "top_structure_stage_fail_reason_rows", "top_execution_block_reason", "top_execution_block_reason_rows", "top_skip_reason", "top_skip_reason_rows")
}

function Append-Elapsed {
    param(
        [object]$Run,
        [double]$ElapsedSeconds
    )

    if (-not (Test-Path $elapsedPath)) {
        Set-Content -Path $elapsedPath -Value "run,scenario,prefix,elapsed_seconds" -Encoding UTF8
    }
    $scenario = $Run.Scenario
    Add-Content -Path $elapsedPath -Value "$($Run.Id),$scenario,$($Run.Prefix),$([math]::Round($ElapsedSeconds, 1))" -Encoding UTF8
}

function Run-Backtest {
    param([object]$Run)

    Copy-PresetToPortable -Run $Run
    Clear-RunLogFolder -Run $Run
    Clear-PortableReportFiles -Run $Run
    Stop-MatchingPortableTerminal

    $configPath = New-PortableConfig -Run $Run
    $startedAt = Get-Date
    Write-Host "[$($Run.Id)] starting $($Run.Prefix)"
    $process = Start-Process -FilePath $TerminalPath -ArgumentList @("/portable", "/config:$configPath") -PassThru -WindowStyle Hidden

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 10
    }

    if (-not $process.HasExited) {
        Stop-Process -Id $process.Id -Force
        throw "[$($Run.Id)] timed out after $TimeoutSeconds seconds"
    }

    Start-Sleep -Seconds 2
    Copy-ReportsToRepo -Run $Run
    Copy-LogsToRepo -Run $Run
    $elapsed = (Get-Date) - $startedAt
    Append-Elapsed -Run $Run -ElapsedSeconds $elapsed.TotalSeconds
    Write-Host "[$($Run.Id)] completed in $([math]::Round($elapsed.TotalSeconds, 1)) seconds"
}

Ensure-Inputs
Sync-EaToPortable

if (Test-Path $elapsedPath) {
    Remove-Item -LiteralPath $elapsedPath -Force
}

foreach ($run in $runs) {
    if ($requestedRunIds -notcontains $run.Id) {
        continue
    }
    Run-Backtest -Run $run
}
