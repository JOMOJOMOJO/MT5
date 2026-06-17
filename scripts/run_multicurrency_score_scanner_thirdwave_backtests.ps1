param(
    [string]$TerminalPath = "C:\Users\windows\AppData\Local\CodexMT5BucketLab\terminal64.exe",
    [int]$TimeoutSeconds = 14400,
    [string[]]$RunIds = @("A", "B", "C"),
    [string]$SeriesName = "2025_thirdwave",
    [string]$FromDate = "2025.01.01",
    [string]$ToDate = "2025.12.31",
    [int]$BaseMagicNumber = 2026060310,
    [ValidateSet("Original", "RegimeComparison", "ScanIntervalComparison", "WaveAudit", "V2Comparison", "V3Comparison", "V4Comparison", "V4SignalQuality", "LowerTFSLFeasibility", "NestedNWave", "NestedRetestConfirmation", "NestedBreakoutQualityRouter", "NestedContextQualityRouterR12", "NestedStructuralBOS", "ConditionFactorial", "FixedConditionBT", "FixedRoom2RLowerTF")]
    [string]$ScenarioSet = "Original",
    [string]$SymbolsOverride = ""
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
        [string]$Scenario,
        [int]$EntrySelectionMode = 0,
        [int]$DiagnosticsLevel = 2,
        [int]$V4SignalMode = 0,
        [int]$ThirdWaveSLMode = 0,
        [double]$RewardR = 1.5,
        [int]$ScanSeconds = 300,
        [int]$ContextTF = 16385,
        [int]$PatternTF = 15,
        [int]$ExecutionTF = 5,
        [int]$MaxPositions = 1,
        [int]$MaxSameCurrencyGroupPositions = 1,
        [double]$MaxRiskPerSymbolPercent = 1.0,
        [double]$MaxTotalOpenRiskPercent = 3.0
    )

    $prefix = "${seriesPrefix}_$Name"
    [pscustomobject]@{
        Id = $Id
        Name = $Name
        Prefix = $prefix
        StrategyMode = $StrategyMode
        DirectionMode = $DirectionMode
        EntrySelectionMode = $EntrySelectionMode
        DiagnosticsLevel = $DiagnosticsLevel
        V4SignalMode = $V4SignalMode
        ThirdWaveSLMode = $ThirdWaveSLMode
        RewardR = $RewardR
        ScanSeconds = $ScanSeconds
        ContextTF = $ContextTF
        PatternTF = $PatternTF
        ExecutionTF = $ExecutionTF
        MaxPositions = $MaxPositions
        MaxSameCurrencyGroupPositions = $MaxSameCurrencyGroupPositions
        MaxRiskPerSymbolPercent = $MaxRiskPerSymbolPercent
        MaxTotalOpenRiskPercent = $MaxTotalOpenRiskPercent
        MagicNumber = $MagicNumber
        Scenario = $Scenario
        IniPath = Join-Path $backtestDir "$prefix.ini"
        PresetPath = Join-Path $presetDir "$prefix.set"
        PresetName = "$prefix.set"
        ReportStem = "${prefix}_report"
        LogFolder = "multicurrency_score_scanner_${SeriesName}_$Name"
    }
}

if ($ScenarioSet -eq "ScanIntervalComparison") {
    $runs = @(
        New-Run -Id "A" -Name "A_regime_best_5m" -StrategyMode 2 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 1) -Scenario "ThirdWave_regime_BOTH_best_5m" -EntrySelectionMode 0 -DiagnosticsLevel 2 -ScanSeconds 300
        New-Run -Id "B" -Name "B_regime_best_10m" -StrategyMode 2 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 2) -Scenario "ThirdWave_regime_BOTH_best_10m" -EntrySelectionMode 0 -DiagnosticsLevel 2 -ScanSeconds 600
        New-Run -Id "C" -Name "C_regime_best_15m" -StrategyMode 2 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 3) -Scenario "ThirdWave_regime_BOTH_best_15m" -EntrySelectionMode 0 -DiagnosticsLevel 2 -ScanSeconds 900
        New-Run -Id "D" -Name "D_regime_all_5m" -StrategyMode 2 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 4) -Scenario "ThirdWave_regime_BOTH_all_5m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "E" -Name "E_regime_all_10m" -StrategyMode 2 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 5) -Scenario "ThirdWave_regime_BOTH_all_10m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -ScanSeconds 600 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "F" -Name "F_regime_all_15m" -StrategyMode 2 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 6) -Scenario "ThirdWave_regime_BOTH_all_15m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -ScanSeconds 900 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
    )
} elseif ($ScenarioSet -eq "WaveAudit") {
    $runs = @(
        New-Run -Id "A" -Name "A_regime_all_5m_wave_audit" -StrategyMode 2 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 1) -Scenario "ThirdWave_regime_BOTH_all_5m_wave_audit" -EntrySelectionMode 1 -DiagnosticsLevel 2 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
    )
} elseif ($ScenarioSet -eq "V2Comparison") {
    $runs = @(
        New-Run -Id "A" -Name "A_current_regime_all_5m" -StrategyMode 2 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 1) -Scenario "ThirdWave_regime_BOTH_all_5m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "B" -Name "B_v2_audit_filtered_all_5m" -StrategyMode 3 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 2) -Scenario "ThirdWave_v2_audit_filtered_BOTH_all_5m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
    )
} elseif ($ScenarioSet -eq "V3Comparison") {
    $runs = @(
        New-Run -Id "A" -Name "A_current_regime_all_5m" -StrategyMode 2 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 1) -Scenario "ThirdWave_regime_BOTH_all_5m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "B" -Name "B_v2_audit_filtered_all_5m" -StrategyMode 3 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 2) -Scenario "ThirdWave_v2_audit_filtered_BOTH_all_5m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "C" -Name "C_v3_entry_timing_all_5m" -StrategyMode 4 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 3) -Scenario "ThirdWave_v3_entry_timing_BOTH_all_5m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
    )
} elseif ($ScenarioSet -eq "V4Comparison") {
    $runs = @(
        New-Run -Id "A" -Name "A_current_regime_all_5m" -StrategyMode 2 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 1) -Scenario "ThirdWave_regime_BOTH_all_5m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "B" -Name "B_v2_audit_filtered_all_5m" -StrategyMode 3 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 2) -Scenario "ThirdWave_v2_audit_filtered_BOTH_all_5m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "C" -Name "C_v3_entry_timing_all_5m" -StrategyMode 4 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 3) -Scenario "ThirdWave_v3_entry_timing_BOTH_all_5m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "D" -Name "D_v4_early_reversal_all_5m" -StrategyMode 5 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 4) -Scenario "ThirdWave_v4_early_reversal_BOTH_all_5m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
    )
} elseif ($ScenarioSet -eq "V4SignalQuality") {
    $runs = @(
        New-Run -Id "A" -Name "A_cur" -StrategyMode 2 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 1) -Scenario "ThirdWave_regime_BOTH_all_5m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "B" -Name "B_v4all" -StrategyMode 5 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 2) -Scenario "ThirdWave_v4_all_signals_BOTH_all_5m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -V4SignalMode 0 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "C" -Name "C_micro" -StrategyMode 5 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 3) -Scenario "ThirdWave_v4_micro_break_only_BOTH_all_5m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -V4SignalMode 1 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "D" -Name "D_candle" -StrategyMode 5 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 4) -Scenario "ThirdWave_v4_candle_reversal_only_BOTH_all_5m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -V4SignalMode 2 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "E" -Name "E_microcandle" -StrategyMode 5 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 5) -Scenario "ThirdWave_v4_micro_or_candle_BOTH_all_5m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -V4SignalMode 3 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "F" -Name "F_noweak" -StrategyMode 5 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 6) -Scenario "ThirdWave_v4_without_weak_signals_BOTH_all_5m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -V4SignalMode 4 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
    )
} elseif ($ScenarioSet -eq "LowerTFSLFeasibility") {
    $runs = @(
        New-Run -Id "A" -Name "A_cur15" -StrategyMode 2 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 1) -Scenario "current_thirdwave_current_sl_1_5R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -V4SignalMode 0 -ThirdWaveSLMode 0 -RewardR 1.5 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "B" -Name "B_mc_cur15" -StrategyMode 5 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 2) -Scenario "v4_micro_or_candle_current_sl_1_5R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -V4SignalMode 3 -ThirdWaveSLMode 0 -RewardR 1.5 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "C" -Name "C_mc_l12" -StrategyMode 5 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 3) -Scenario "v4_micro_or_candle_lower_tf_sl_1_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -V4SignalMode 3 -ThirdWaveSLMode 1 -RewardR 1.2 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "D" -Name "D_mc_l13" -StrategyMode 5 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 4) -Scenario "v4_micro_or_candle_lower_tf_sl_1_3R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -V4SignalMode 3 -ThirdWaveSLMode 1 -RewardR 1.3 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "E" -Name "E_mc_l15" -StrategyMode 5 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 5) -Scenario "v4_micro_or_candle_lower_tf_sl_1_5R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -V4SignalMode 3 -ThirdWaveSLMode 1 -RewardR 1.5 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "F" -Name "F_nw_l12" -StrategyMode 5 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 6) -Scenario "v4_without_weak_lower_tf_sl_1_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -V4SignalMode 4 -ThirdWaveSLMode 1 -RewardR 1.2 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "G" -Name "G_nw_l13" -StrategyMode 5 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 7) -Scenario "v4_without_weak_lower_tf_sl_1_3R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -V4SignalMode 4 -ThirdWaveSLMode 1 -RewardR 1.3 -ScanSeconds 300 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
    )
} elseif ($ScenarioSet -eq "NestedNWave") {
    $runs = @(
        New-Run -Id "A" -Name "A_current_thirdwave" -StrategyMode 2 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 1) -Scenario "current_ThirdWave_regime_BOTH_all_5m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 1.5 -ScanSeconds 300 -ContextTF 16385 -PatternTF 15 -ExecutionTF 5 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "B" -Name "B_v4_early_reversal" -StrategyMode 5 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 2) -Scenario "v4_early_reversal_BOTH_all_5m" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 1.5 -ScanSeconds 300 -ContextTF 16385 -PatternTF 15 -ExecutionTF 5 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "C" -Name "C_nested_best" -StrategyMode 6 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 3) -Scenario "Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R" -EntrySelectionMode 0 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 1 -MaxSameCurrencyGroupPositions 1 -MaxRiskPerSymbolPercent 1.0 -MaxTotalOpenRiskPercent 3.0
        New-Run -Id "D" -Name "D_nested_all" -StrategyMode 6 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 4) -Scenario "Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
    )
} elseif ($ScenarioSet -eq "NestedRetestConfirmation") {
    $runs = @(
        New-Run -Id "C" -Name "C_nested_best" -StrategyMode 6 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 3) -Scenario "Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R" -EntrySelectionMode 0 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 1 -MaxSameCurrencyGroupPositions 1 -MaxRiskPerSymbolPercent 1.0 -MaxTotalOpenRiskPercent 3.0
        New-Run -Id "D" -Name "D_nested_all" -StrategyMode 6 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 4) -Scenario "Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "E" -Name "E_retest_best" -StrategyMode 7 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 5) -Scenario "Nested_NWave_RetestConfirmation_BOTH_best_H4_H1_M15_2R" -EntrySelectionMode 0 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 1 -MaxSameCurrencyGroupPositions 1 -MaxRiskPerSymbolPercent 1.0 -MaxTotalOpenRiskPercent 3.0
        New-Run -Id "F" -Name "F_retest_all" -StrategyMode 7 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 6) -Scenario "Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
    )
} elseif ($ScenarioSet -eq "NestedBreakoutQualityRouter") {
    $runs = @(
        New-Run -Id "C" -Name "C_nested_best" -StrategyMode 6 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 3) -Scenario "Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R" -EntrySelectionMode 0 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 1 -MaxSameCurrencyGroupPositions 1 -MaxRiskPerSymbolPercent 1.0 -MaxTotalOpenRiskPercent 3.0
        New-Run -Id "D" -Name "D_nested_all" -StrategyMode 6 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 4) -Scenario "Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "E" -Name "E_retest_best" -StrategyMode 7 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 5) -Scenario "Nested_NWave_RetestConfirmation_BOTH_best_H4_H1_M15_2R" -EntrySelectionMode 0 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 1 -MaxSameCurrencyGroupPositions 1 -MaxRiskPerSymbolPercent 1.0 -MaxTotalOpenRiskPercent 3.0
        New-Run -Id "F" -Name "F_retest_all" -StrategyMode 7 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 6) -Scenario "Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "G" -Name "G_router_best" -StrategyMode 8 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 7) -Scenario "Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R" -EntrySelectionMode 0 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 1 -MaxSameCurrencyGroupPositions 1 -MaxRiskPerSymbolPercent 1.0 -MaxTotalOpenRiskPercent 3.0
        New-Run -Id "H" -Name "H_router_all" -StrategyMode 8 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 8) -Scenario "Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
    )
} elseif ($ScenarioSet -eq "NestedContextQualityRouterR12") {
    $runs = @(
        New-Run -Id "A" -Name "A_nested_all_r12" -StrategyMode 6 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 1) -Scenario "Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_1_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 1.2 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "B" -Name "B_retest_all_r12" -StrategyMode 7 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 2) -Scenario "Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_1_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 1.2 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "C" -Name "C_breakout_router_all_r12" -StrategyMode 8 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 3) -Scenario "Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_1_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 1.2 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "D" -Name "D_context_router_all_r12" -StrategyMode 9 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 4) -Scenario "Nested_NWave_ContextQualityRouter_BOTH_all_H4_H1_M15_1_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 1.2 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "E" -Name "E_context_router_v2_all_r12" -StrategyMode 10 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 5) -Scenario "Nested_NWave_ContextQualityRouterV2_BOTH_all_H4_H1_M15_1_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 1.2 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "F" -Name "F_context_router_v3_all_r12" -StrategyMode 11 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 6) -Scenario "Nested_NWave_ContextQualityRouterV3_BOTH_all_H4_H1_M15_1_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 1.2 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
    )
} elseif ($ScenarioSet -eq "NestedStructuralBOS") {
    $runs = @(
        New-Run -Id "A" -Name "A_nested_all" -StrategyMode 6 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 1) -Scenario "Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "B" -Name "B_retest_all" -StrategyMode 7 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 2) -Scenario "Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "C" -Name "C_breakout_router_all" -StrategyMode 8 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 3) -Scenario "Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "D" -Name "D_context_router_v2_all" -StrategyMode 10 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 4) -Scenario "Nested_NWave_ContextQualityRouterV2_BOTH_all_H4_H1_M15_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "E" -Name "E_structural_bos_all" -StrategyMode 12 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 5) -Scenario "Nested_NWave_StructuralBOS_BOTH_all_H4_H1_M15_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "F" -Name "F_structural_bos_v2_all" -StrategyMode 13 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 6) -Scenario "Nested_NWave_StructuralBOS_V2_BOTH_all_H4_H1_M15_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
    )
} elseif ($ScenarioSet -eq "ConditionFactorial") {
    $runs = @(
        New-Run -Id "A" -Name "A_condition_factorial_candidates" -StrategyMode 14 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 1) -Scenario "Nested_ConditionFactorial_Candidates_BOTH_all_H4_H1_M15_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
    )
} elseif ($ScenarioSet -eq "FixedConditionBT") {
    $runs = @(
        New-Run -Id "B" -Name "B_fixed_room2r" -StrategyMode 15 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 2) -Scenario "Nested_Fixed_Room2R_BOTH_all_H4_H1_M15_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "C" -Name "C_fixed_h4ma_room2r" -StrategyMode 16 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 3) -Scenario "Nested_Fixed_H4MA_Room2R_BOTH_all_H4_H1_M15_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "D" -Name "D_fixed_h4ma_m15close_room2r" -StrategyMode 17 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 4) -Scenario "Nested_Fixed_H4MA_M15Close_Room2R_BOTH_all_H4_H1_M15_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "E" -Name "E_fixed_h4fib_room2r" -StrategyMode 18 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 5) -Scenario "Nested_Fixed_H4Fib_Room2R_BOTH_all_H4_H1_M15_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
        New-Run -Id "F" -Name "F_fixed_h4ma_h4fib_m15close_room2r" -StrategyMode 19 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 6) -Scenario "Nested_Fixed_H4MA_H4Fib_M15Close_Room2R_BOTH_all_H4_H1_M15_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16388 -PatternTF 16385 -ExecutionTF 15 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
    )
} elseif ($ScenarioSet -eq "FixedRoom2RLowerTF") {
    $runs = @(
        New-Run -Id "L" -Name "L_fixed_room2r_lower_tf" -StrategyMode 20 -DirectionMode 0 -MagicNumber ($BaseMagicNumber + 20) -Scenario "Nested_Fixed_Room2R_LOWER_TF_BOTH_all_H1_M15_M5_2R" -EntrySelectionMode 1 -DiagnosticsLevel 2 -RewardR 2.0 -ScanSeconds 300 -ContextTF 16385 -PatternTF 15 -ExecutionTF 5 -MaxPositions 50 -MaxSameCurrencyGroupPositions 50 -MaxRiskPerSymbolPercent 100000.0 -MaxTotalOpenRiskPercent 100000.0
    )
} elseif ($ScenarioSet -eq "RegimeComparison") {
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
    $insertedEntrySelectionMode = $false
    $insertedDiagnosticsLevel = $false
    $insertedV4SignalMode = $false
    $insertedThirdWaveSLMode = $false
    $insertedRewardR = $false
    $insertedSymbols = $false
    foreach ($line in $lines) {
        if ($line -match '^InpSymbols=' -and $SymbolsOverride.Trim()) {
            $out.Add("InpSymbols=$($SymbolsOverride.Trim())")
            $insertedSymbols = $true
            continue
        }
        if ($line -match '^InpScanSeconds=') {
            $out.Add("InpScanSeconds=$($Run.ScanSeconds)||$($Run.ScanSeconds)||60||3600||N")
            continue
        }
        if ($line -match '^InpResearchStrategyMode=') {
            $out.Add("InpResearchStrategyMode=$($Run.StrategyMode)||$($Run.StrategyMode)||0||20||N")
            $insertedStrategyMode = $true
            continue
        }
        if ($line -match '^InpEntrySelectionMode=') {
            $out.Add("InpEntrySelectionMode=$($Run.EntrySelectionMode)||$($Run.EntrySelectionMode)||0||1||N")
            $insertedEntrySelectionMode = $true
            continue
        }
        if ($line -match '^InpDiagnosticsLevel=') {
            $out.Add("InpDiagnosticsLevel=$($Run.DiagnosticsLevel)||$($Run.DiagnosticsLevel)||0||3||N")
            $insertedDiagnosticsLevel = $true
            continue
        }
        if ($line -match '^InpV4ReversalSignalMode=') {
            $out.Add("InpV4ReversalSignalMode=$($Run.V4SignalMode)||$($Run.V4SignalMode)||0||4||N")
            $insertedV4SignalMode = $true
            continue
        }
        if ($line -match '^InpThirdWaveSLMode=') {
            $out.Add("InpThirdWaveSLMode=$($Run.ThirdWaveSLMode)||$($Run.ThirdWaveSLMode)||0||1||N")
            $insertedThirdWaveSLMode = $true
            continue
        }
        if ($line -match '^InpTradeDirectionMode=') {
            $out.Add("InpTradeDirectionMode=$($Run.DirectionMode)||$($Run.DirectionMode)||0||2||N")
            continue
        }
        if ($line -match '^InpContextTF=') {
            $out.Add("InpContextTF=$($Run.ContextTF)||$($Run.ContextTF)||1||49153||N")
            continue
        }
        if ($line -match '^InpPatternTF=') {
            $out.Add("InpPatternTF=$($Run.PatternTF)||$($Run.PatternTF)||1||49153||N")
            continue
        }
        if ($line -match '^InpExecutionTF=') {
            $out.Add("InpExecutionTF=$($Run.ExecutionTF)||$($Run.ExecutionTF)||1||49153||N")
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
        if ($line -match '^InpMaxPositions=') {
            $out.Add("InpMaxPositions=$($Run.MaxPositions)||$($Run.MaxPositions)||1||100||N")
            continue
        }
        if ($line -match '^InpMaxSameCurrencyGroupPositions=') {
            $out.Add("InpMaxSameCurrencyGroupPositions=$($Run.MaxSameCurrencyGroupPositions)||$($Run.MaxSameCurrencyGroupPositions)||1||100||N")
            continue
        }
        if ($line -match '^InpMaxRiskPerSymbolPercent=') {
            $out.Add("InpMaxRiskPerSymbolPercent=$($Run.MaxRiskPerSymbolPercent.ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture))||$($Run.MaxRiskPerSymbolPercent.ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture))||0.10||100000.00||N")
            continue
        }
        if ($line -match '^InpMaxTotalOpenRiskPercent=') {
            $out.Add("InpMaxTotalOpenRiskPercent=$($Run.MaxTotalOpenRiskPercent.ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture))||$($Run.MaxTotalOpenRiskPercent.ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture))||0.10||100000.00||N")
            continue
        }
        if ($line -match '^InpRewardR=') {
            $rewardText = $Run.RewardR.ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture)
            $out.Add("InpRewardR=$rewardText||$rewardText||1.00||3.00||N")
            $insertedRewardR = $true
            continue
        }
        if ($line -match '^InpLogFolder=') {
            $out.Add("InpLogFolder=$($Run.LogFolder)")
            continue
        }
        $out.Add($line)
        if (-not $insertedStrategyMode -and $line -match '^InpExecutionTF=') {
            $out.Add("InpResearchStrategyMode=$($Run.StrategyMode)||$($Run.StrategyMode)||0||20||N")
            $insertedStrategyMode = $true
        }
        if (-not $insertedEntrySelectionMode -and $line -match '^InpResearchStrategyMode=') {
            $out.Add("InpEntrySelectionMode=$($Run.EntrySelectionMode)||$($Run.EntrySelectionMode)||0||1||N")
            $insertedEntrySelectionMode = $true
        }
        if (-not $insertedDiagnosticsLevel -and $line -match '^InpEntrySelectionMode=') {
            $out.Add("InpDiagnosticsLevel=$($Run.DiagnosticsLevel)||$($Run.DiagnosticsLevel)||0||3||N")
            $insertedDiagnosticsLevel = $true
        }
        if (-not $insertedV4SignalMode -and $line -match '^InpDiagnosticsLevel=') {
            $out.Add("InpV4ReversalSignalMode=$($Run.V4SignalMode)||$($Run.V4SignalMode)||0||4||N")
            $insertedV4SignalMode = $true
        }
        if (-not $insertedThirdWaveSLMode -and $line -match '^InpV4ReversalSignalMode=') {
            $out.Add("InpThirdWaveSLMode=$($Run.ThirdWaveSLMode)||$($Run.ThirdWaveSLMode)||0||1||N")
            $insertedThirdWaveSLMode = $true
        }
        if (-not $insertedEntrySelectionMode -and $insertedStrategyMode -and $line -match '^InpExecutionTF=') {
            $out.Add("InpEntrySelectionMode=$($Run.EntrySelectionMode)||$($Run.EntrySelectionMode)||0||1||N")
            $insertedEntrySelectionMode = $true
        }
        if (-not $insertedDiagnosticsLevel -and $insertedEntrySelectionMode -and $line -match '^InpExecutionTF=') {
            $out.Add("InpDiagnosticsLevel=$($Run.DiagnosticsLevel)||$($Run.DiagnosticsLevel)||0||3||N")
            $insertedDiagnosticsLevel = $true
        }
        if (-not $insertedV4SignalMode -and $insertedDiagnosticsLevel -and $line -match '^InpExecutionTF=') {
            $out.Add("InpV4ReversalSignalMode=$($Run.V4SignalMode)||$($Run.V4SignalMode)||0||4||N")
            $insertedV4SignalMode = $true
        }
        if (-not $insertedThirdWaveSLMode -and $insertedV4SignalMode -and $line -match '^InpExecutionTF=') {
            $out.Add("InpThirdWaveSLMode=$($Run.ThirdWaveSLMode)||$($Run.ThirdWaveSLMode)||0||1||N")
            $insertedThirdWaveSLMode = $true
        }
    }
    if (-not $insertedStrategyMode) {
        $out.Add("InpResearchStrategyMode=$($Run.StrategyMode)||$($Run.StrategyMode)||0||20||N")
    }
    if (-not $insertedEntrySelectionMode) {
        $out.Add("InpEntrySelectionMode=$($Run.EntrySelectionMode)||$($Run.EntrySelectionMode)||0||1||N")
    }
    if (-not $insertedDiagnosticsLevel) {
        $out.Add("InpDiagnosticsLevel=$($Run.DiagnosticsLevel)||$($Run.DiagnosticsLevel)||0||3||N")
    }
    if (-not $insertedV4SignalMode) {
        $out.Add("InpV4ReversalSignalMode=$($Run.V4SignalMode)||$($Run.V4SignalMode)||0||4||N")
    }
    if (-not $insertedThirdWaveSLMode) {
        $out.Add("InpThirdWaveSLMode=$($Run.ThirdWaveSLMode)||$($Run.ThirdWaveSLMode)||0||1||N")
    }
    if (-not $insertedRewardR) {
        $rewardText = $Run.RewardR.ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture)
        $out.Add("InpRewardR=$rewardText||$rewardText||1.00||3.00||N")
    }
    if (-not $insertedSymbols -and $SymbolsOverride.Trim()) {
        $out.Add("InpSymbols=$($SymbolsOverride.Trim())")
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
    $waveAuditFiles = @(Get-ChildItem -Path $logDir -File -Filter "thirdwave_wave_audit_*.csv")
    $summaryFiles = @(Get-ChildItem -Path $logDir -File -Filter "thirdwave_summary_*.csv")
    $nestedSignalFiles = @(Get-ChildItem -Path $logDir -File -Filter "nested_nwave_signal_diagnostics_*.csv")
    $nestedTradeFiles = @(Get-ChildItem -Path $logDir -File -Filter "nested_nwave_trade_diagnostics_*.csv")
    $nestedSummaryFiles = @(Get-ChildItem -Path $logDir -File -Filter "nested_nwave_summary_*.csv")

    Join-CsvFiles -Files $scanFiles -OutputPath (Join-Path $backtestDir "$($Run.Prefix)_scan_diagnostics.csv") -EmptyHeader @("time", "event", "last_scan_bar_time", "scan_elapsed_ms", "reason")
    Join-CsvFiles -Files $signalFiles -OutputPath (Join-Path $backtestDir "$($Run.Prefix)_thirdwave_signal_diagnostics.csv") -EmptyHeader @("time", "symbol", "direction", "higher_tf_trend", "mid_tf_pullback_status", "lower_tf_reversal_status", "regime", "regime_reason", "higher_tf_swing_state", "ema_slope", "trend_strength", "volatility_state", "entry_allowed_by_regime", "blocked_by_regime_reason", "lower_reversal_quality", "pullback_depth_atr", "sl_atr", "setup_pass", "entry_pass", "final_entry_pass", "skip_reason", "structure_stage_fail_reason", "execution_block_reason", "higher_tf_trend_pass", "mid_tf_pullback_pass", "lower_tf_reversal_pass", "structure_sl_pass", "rr_pass", "v2_filter_pass", "v2_filter_fail_reason", "v3_filter_pass", "v3_filter_fail_reason", "v3_momentum_exhaustion_score", "v3_momentum_exhausted", "v3_recent_move_atr", "v3_consecutive_directional_bars", "v3_close_to_recent_extreme_atr", "reversal_signal_type", "v4_block_reason", "v4_signal_mode", "v4_signal_mode_pass", "v4_signal_mode_blocked", "bars_since_pullback_extreme", "bars_since_reversal_signal", "distance_from_reversal_signal_to_entry_atr", "impulse_consumed_pct", "pre_entry_momentum_score", "reversal_strength_score", "spread_atr", "max_spread_atr", "spread_guard_pass", "spread_guard_blocked", "spread_points", "atr_value", "entry_price", "sl", "tp", "mid_tf_structure_sl", "lower_tf_reversal_sl", "mid_tf_structure_sl_atr", "lower_tf_reversal_sl_atr", "lower_tf_reversal_sl_status", "risk_r", "rr", "swing_high", "swing_low", "structure_sl_source", "strategy_name")
    Join-CsvFiles -Files $tradeFiles -OutputPath (Join-Path $backtestDir "$($Run.Prefix)_thirdwave_trade_diagnostics.csv") -EmptyHeader @("time", "symbol", "direction", "event", "regime", "regime_reason", "higher_tf_swing_state", "ema_slope", "trend_strength", "volatility_state", "entry_allowed_by_regime", "blocked_by_regime_reason", "lower_reversal_quality", "pullback_depth_atr", "sl_atr", "order_retcode", "order_comment", "entry_price", "sl", "tp", "mid_tf_structure_sl", "lower_tf_reversal_sl", "mid_tf_structure_sl_atr", "lower_tf_reversal_sl_atr", "lower_tf_reversal_sl_status", "volume", "risk_r", "rr", "skip_reason", "structure_stage_fail_reason", "execution_block_reason", "v2_filter_pass", "v2_filter_fail_reason", "v3_filter_pass", "v3_filter_fail_reason", "v3_momentum_exhaustion_score", "v3_momentum_exhausted", "v3_recent_move_atr", "v3_consecutive_directional_bars", "v3_close_to_recent_extreme_atr", "reversal_signal_type", "v4_block_reason", "v4_signal_mode", "v4_signal_mode_pass", "v4_signal_mode_blocked", "bars_since_pullback_extreme", "bars_since_reversal_signal", "distance_from_reversal_signal_to_entry_atr", "impulse_consumed_pct", "pre_entry_momentum_score", "reversal_strength_score", "spread_atr", "max_spread_atr", "spread_guard_pass", "spread_guard_blocked", "spread_points", "atr_value", "strategy_name")
    Join-CsvFiles -Files $waveAuditFiles -OutputPath (Join-Path $backtestDir "$($Run.Prefix)_thirdwave_wave_audit.csv") -EmptyHeader @("time", "event", "symbol", "direction", "entry_price", "sl", "tp", "mid_tf_structure_sl", "lower_tf_reversal_sl", "mid_tf_structure_sl_atr", "lower_tf_reversal_sl_atr", "lower_tf_reversal_sl_status", "result_R", "profit", "regime", "session", "scan_interval", "entry_selection_mode", "v4_signal_mode", "thirdwave_sl_mode", "v4_signal_mode_pass", "v4_signal_mode_blocked", "higher_tf", "higher_swing_low_1", "higher_swing_high_1", "higher_swing_low_2", "higher_swing_high_2", "higher_structure_state", "higher_trend_age_bars", "higher_ema_slope", "higher_atr", "mid_tf", "impulse_start_price", "impulse_end_price", "pullback_extreme_price", "pullback_depth_pct", "pullback_depth_atr", "pullback_bars", "pullback_broke_origin", "pullback_structure_low_or_high", "distance_from_pullback_extreme_to_entry_atr", "distance_from_pullback_extreme_to_entry_pct_of_impulse", "lower_tf", "minor_reversal_level", "reclaim_or_breakdown_price", "bars_since_reclaim_or_breakdown", "entry_distance_from_reclaim_atr", "entry_distance_from_reclaim_points", "lower_reversal_quality", "lower_reversal_quality_score", "sl_atr", "risk_r", "rr", "spread_atr", "structure_stage_fail_reason", "execution_block_reason", "v2_filter_pass", "v2_filter_fail_reason", "v3_filter_pass", "v3_filter_fail_reason", "v3_momentum_exhaustion_score", "v3_momentum_exhausted", "v3_recent_move_atr", "v3_consecutive_directional_bars", "v3_close_to_recent_extreme_atr", "reversal_signal_type", "v4_block_reason", "bars_since_pullback_extreme", "bars_since_reversal_signal", "distance_from_reversal_signal_to_entry_atr", "impulse_consumed_pct", "pre_entry_momentum_score", "reversal_strength_score", "wave_audit_label", "wave_audit_reason", "strategy_name")
    Join-CsvFiles -Files $summaryFiles -OutputPath (Join-Path $backtestDir "$($Run.Prefix)_thirdwave_summary.csv") -EmptyHeader @("time", "strategy_name", "v4_signal_mode", "thirdwave_sl_mode", "evaluations", "long_evaluations", "short_evaluations", "setup_pass", "entry_pass", "orders_sent", "orders_failed", "higher_tf_trend_pass", "mid_tf_pullback_pass", "lower_tf_reversal_pass", "structure_sl_pass", "rr_pass", "spread_guard_pass", "spread_guard_blocked", "final_entry_pass", "v2_filter_evaluations", "v2_filter_pass", "v2_filter_fail", "v2_filter_deep_pullback", "v2_filter_trend_too_old", "v2_filter_reclaim_chase_too_far", "v3_filter_evaluations", "v3_filter_pass", "v3_filter_fail", "v3_filter_invalid_position", "v3_filter_late_entry", "v3_filter_chasing_entry", "v3_filter_reclaim_chase", "v3_filter_pullback_chase", "v3_filter_momentum_exhausted", "v4_reversal_evaluations", "v4_reversal_pass", "v4_reversal_fail", "v4_confirmed_fractal", "v4_early_higher_low", "v4_early_lower_high", "v4_momentum_turn", "v4_candle_reversal", "v4_micro_break", "v4_unclear", "v4_impulse_consumed_blocked", "regime_trend_up", "regime_trend_down", "regime_range", "regime_transition", "regime_exhaustion", "regime_unknown", "regime_allowed", "regime_blocked", "regime_block_long_requires_trend_up", "regime_block_short_requires_trend_down", "long_higher_tf_trend_pass", "long_mid_tf_pullback_pass", "long_lower_tf_reversal_pass", "long_structure_sl_pass", "long_rr_pass", "long_spread_guard_pass", "long_spread_guard_blocked", "long_final_entry_pass", "short_higher_tf_trend_pass", "short_mid_tf_pullback_pass", "short_lower_tf_reversal_pass", "short_structure_sl_pass", "short_rr_pass", "short_spread_guard_pass", "short_spread_guard_blocked", "short_final_entry_pass", "no_higher_tf_trend", "trend_broken", "no_mid_pullback", "pullback_too_shallow", "pullback_too_deep", "no_lower_reversal", "lower_reversal_quality_low", "sl_too_close", "sl_too_tight", "sl_too_wide", "invalid_stops", "rr_too_low", "existing_position", "market_closed", "spread_guard", "data_unavailable", "atr_unavailable", "research_excluded", "regime_requires_trend_up", "regime_requires_trend_down", "unknown", "execution_spread_guard", "execution_trading_disabled", "execution_no_entry_signal", "execution_position_limit", "execution_risk_stop", "execution_risk_limit", "execution_invalid", "execution_order_failed", "execution_unknown", "top_structure_stage_fail_reason", "top_structure_stage_fail_reason_rows", "top_execution_block_reason", "top_execution_block_reason_rows", "top_skip_reason", "top_skip_reason_rows", "top_v2_filter_fail_reason", "top_v2_filter_fail_reason_rows", "top_v3_filter_fail_reason", "top_v3_filter_fail_reason_rows", "top_v4_reversal_signal", "top_v4_reversal_signal_rows")
    $nestedRetestFields = @("retest_confirmation_mode", "retest_detected", "retest_held", "retest_trigger_pass", "retest_failed", "original_neckline_break_time", "retest_detected_time", "retest_trigger_time", "retest_bars_after_breakout", "entry_delay_bars", "retest_depth_atr", "retest_zone_atr", "retest_reclaim_price", "retest_distance_from_neckline_atr", "false_break_return_inside_neckline", "retest_quality", "retest_failure_reason")
    Join-CsvFiles -Files $nestedSignalFiles -OutputPath (Join-Path $backtestDir "$($Run.Prefix)_nested_nwave_signal_diagnostics.csv") -EmptyHeader (@("time", "event", "symbol", "direction", "session", "entry_selection_mode", "scan_interval", "strategy_name", "label", "fail_reason", "execution_block_reason", "fib_zone", "h4_trend_state", "h1_counter_trend_state", "neckline_break_label", "h4_impulse_pass", "h4_pullback_zone_pass", "h1_counter_trend_pass", "neckline_pass", "structure_sl_pass", "rr_pass", "spread_guard_pass", "spread_guard_blocked", "setup_pass", "entry_pass", "final_entry_pass", "h4_impulse_high", "h4_impulse_low", "h4_fib_retracement_pct", "h4_atr", "h1_atr", "m15_atr", "spread_atr", "spread_points", "neckline_price", "neckline_break_close_price", "right_side_level", "entry_price", "sl", "tp", "volume", "risk_r", "rr", "bars_since_right_side", "distance_neckline_to_entry", "distance_neckline_to_entry_atr", "distance_right_side_to_entry", "distance_right_side_to_entry_atr", "sl_points", "sl_atr", "tp_points", "tp_atr", "quality_score") + $nestedRetestFields)
    Join-CsvFiles -Files $nestedTradeFiles -OutputPath (Join-Path $backtestDir "$($Run.Prefix)_nested_nwave_trade_diagnostics.csv") -EmptyHeader (@("time", "event", "symbol", "direction", "session", "order_retcode", "order_comment", "strategy_name", "label", "fail_reason", "execution_block_reason", "fib_zone", "h4_trend_state", "h1_counter_trend_state", "neckline_break_label", "entry_price", "sl", "tp", "volume", "risk_r", "rr", "sl_points", "sl_atr", "tp_points", "tp_atr", "neckline_price", "neckline_break_close_price", "right_side_level", "bars_since_right_side", "distance_neckline_to_entry_atr", "distance_right_side_to_entry_atr", "spread_atr", "spread_points", "quality_score") + $nestedRetestFields)
    Join-CsvFiles -Files $nestedSummaryFiles -OutputPath (Join-Path $backtestDir "$($Run.Prefix)_nested_nwave_summary.csv") -EmptyHeader @("time", "strategy_name", "entry_selection_mode", "context_tf", "pattern_tf", "execution_tf", "reward_r", "evaluations", "long_evaluations", "short_evaluations", "h4_impulse_pass", "pullback_zone_pass", "h1_counter_trend_pass", "neckline_pass", "structure_sl_pass", "rr_pass", "spread_guard_pass", "spread_guard_blocked", "final_entry_pass", "orders_sent", "orders_failed", "data_unavailable", "atr_unavailable", "research_excluded", "no_h4_nwave", "too_shallow_pullback", "too_deep_pullback", "no_h1_counter_trend_nwave", "no_clear_neckline", "no_neckline_break", "sl_too_tight", "sl_too_wide", "invalid_structure", "spread_guard", "existing_position", "execution_blocked", "clean_nested_nwave_entry", "neckline_break_initial", "neckline_break_late", "chasing_after_break", "retest_detected", "retest_held", "retest_trigger_pass", "no_retest_confirmation_break", "no_retest_detected", "retest_invalidated", "no_retest_trigger", "unknown", "top_fail_reason", "top_fail_reason_rows")
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
