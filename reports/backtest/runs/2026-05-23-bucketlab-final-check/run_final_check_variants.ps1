param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path)
$ErrorActionPreference = "Stop"
$portable = "C:\Users\windows\AppData\Local\CodexMT5BucketLab"
$terminal = Join-Path $portable "terminal64.exe"
$common = "C:\Users\windows\AppData\Roaming\MetaQuotes\Terminal\Common\Files"
$basePreset = Join-Path $RepoRoot "reports\presets\ExpectedValue_LongOnly_BucketLab_v2_5_shallow_candidate_2025.set"
$presetTarget = Join-Path $portable "MQL5\Profiles\Tester"

function Set-OrAddPresetValue {
    param([System.Collections.Generic.List[string]]$Lines, [string]$Key, [string]$Value, [string]$Tail = "")
    for($i = 0; $i -lt $Lines.Count; $i++) {
        if($Lines[$i] -match ("^" + [regex]::Escape($Key) + "=")) {
            $parts = $Lines[$i] -split "\|\|"
            $parts[0] = "$Key=$Value"
            if($parts.Count -gt 1) { $parts[1] = $Value }
            $Lines[$i] = ($parts -join "||")
            return
        }
    }
    if($Tail) { $Lines.Add("$Key=$Value||$Value||$Tail") } else { $Lines.Add("$Key=$Value") }
}

$variants = @(
    @{ Name="ref_v2_5"; Label="final_ref_v2_5"; Magic="2026052301"; Overrides=@{} },
    @{ Name="mid_range_family"; Label="final_mid_range_family"; Magic="2026052302"; Overrides=@{ InpEnableMidRangeContinuationBucket="true" } },
    @{ Name="sl_m1_swing"; Label="final_sl_m1_swing"; Magic="2026052303"; Overrides=@{ InpStopMode="1" } },
    @{ Name="sl_m5_swing"; Label="final_sl_m5_swing"; Magic="2026052304"; Overrides=@{ InpStopMode="2" } },
    @{ Name="tp_recent_high_or_r"; Label="final_tp_recent_high_or_r"; Magic="2026052305"; Overrides=@{ InpTPMode="1" } },
    @{ Name="hold_long_r135"; Label="final_hold_long_r135"; Magic="2026052306"; Overrides=@{ InpMaxHoldBars="45"; InpTargetRMultiple="1.35"; InpCooldownBars="6" } },
    @{ Name="second_entry_conservative"; Label="final_second_entry_conservative"; Magic="2026052307"; Overrides=@{ InpCooldownBars="6"; InpAdditionalEntryMinDayPnLPercent="0.0"; InpAdditionalEntryMinOpenProfitR="0.35"; InpAdditionalEntryMinATRRatio="1.50"; InpAdditionalEntryMinUpPressure="0.65"; InpAdditionalEntryMaxDownPressure="0.35"; InpAdditionalEntryPreferredMaxRiskDistancePips="14.0" } },
    @{ Name="one_position_control"; Label="final_one_position_control"; Magic="2026052308"; Overrides=@{ InpMaxOpenPositions="1" } }
)

$results = @()
foreach($variant in $variants) {
    $variantDir = Join-Path $PSScriptRoot $variant.Name
    $rawDir = Join-Path $variantDir "raw"
    $iniDir = Join-Path $variantDir "ini"
    New-Item -ItemType Directory -Force -Path $rawDir,$iniDir | Out-Null
    $presetFile = "ExpectedValue_LongOnly_BucketLab_$($variant.Label)_2025.set"
    $presetPath = Join-Path $RepoRoot "reports\presets\$presetFile"
    $lines = [System.Collections.Generic.List[string]](Get-Content -LiteralPath $basePreset)
    Set-OrAddPresetValue $lines "InpMagicNumber" $variant.Magic
    Set-OrAddPresetValue $lines "InpPresetName" "ExpectedValue_LongOnly_BucketLab_$($variant.Label)_2025"
    Set-OrAddPresetValue $lines "InpEventLogFileName" "mt5_company_expected_value_long_bucketlab_$($variant.Name)_events.csv"
    Set-OrAddPresetValue $lines "InpSummaryFileName" "mt5_company_expected_value_long_bucketlab_$($variant.Name)_summary.csv"
    Set-OrAddPresetValue $lines "InpMonthlySummaryFileName" "mt5_company_expected_value_long_bucketlab_$($variant.Name)_monthly.csv"
    Set-OrAddPresetValue $lines "InpLogNoSignalDiagnostics" "false" "0||true||N"
    Set-OrAddPresetValue $lines "InpLogBucketNearMissDiagnostics" "false" "0||true||N"
    Set-OrAddPresetValue $lines "InpNearMissMinScore" "5.20" "0.10||7.0||N"
    foreach($key in $variant.Overrides.Keys) {
        Set-OrAddPresetValue $lines $key ([string]$variant.Overrides[$key])
    }
    Set-Content -LiteralPath $presetPath -Value $lines -Encoding ASCII
    Copy-Item -LiteralPath $presetPath -Destination (Join-Path $presetTarget $presetFile) -Force

    $reportName = "long_bucketlab_$($variant.Name)_2025"
    $iniPath = Join-Path $iniDir "$reportName.ini"
@"
[Experts]
Enabled=1
AllowLiveTrading=0
AllowDllImport=0
Account=0
Profile=0

[Tester]
Expert=dev\mql\Experts\ExpectedValue_LongOnly_BucketLab.ex5
ExpertParameters=$presetFile
Symbol=USDJPY
Period=M1
Model=4
ExecutionMode=0
Optimization=0
OptimizationCriterion=6
FromDate=2025.01.01
ToDate=2025.12.31
ForwardMode=0
Deposit=100
Currency=USD
Leverage=1:100
UseLocal=1
UseRemote=0
UseCloud=0
Visual=0
ReplaceReport=1
ShutdownTerminal=1
Report=$reportName
"@ | Set-Content -LiteralPath $iniPath -Encoding ASCII

    $process = Start-Process -FilePath $terminal -ArgumentList @("/portable", "/config:$iniPath") -WorkingDirectory $portable -PassThru -WindowStyle Hidden
    if(-not $process.WaitForExit(360000)) {
        Stop-Process -Id $process.Id -Force
        throw "MT5 backtest timed out for $($variant.Name)"
    }
    Copy-Item -LiteralPath (Join-Path $common "mt5_company_expected_value_long_bucketlab_$($variant.Name)_events.csv") -Destination (Join-Path $rawDir "events.csv") -Force
    Copy-Item -LiteralPath (Join-Path $common "mt5_company_expected_value_long_bucketlab_$($variant.Name)_summary.csv") -Destination (Join-Path $rawDir "summary.csv") -Force
    Copy-Item -LiteralPath (Join-Path $common "mt5_company_expected_value_long_bucketlab_$($variant.Name)_monthly.csv") -Destination (Join-Path $rawDir "monthly.csv") -Force
    $summary = Import-Csv -LiteralPath (Join-Path $rawDir "summary.csv") -Delimiter ";" | Select-Object -Last 1
    $events = Import-Csv -LiteralPath (Join-Path $rawDir "events.csv") -Delimiter ";"
    $stopCount = @($events | Where-Object { $_.event -eq "stop_condition_triggered" }).Count
    $marginRejects = @($events | Where-Object {
        $_.event -eq "entry_blocked" -and
        ($_.reason -match "margin" -or $_.detail -match "margin")
    }).Count
    $timeoutExits = @($events | Where-Object { $_.event -eq "exit" -and $_.reason -eq "TIMEOUT" }).Count
    $slExits = @($events | Where-Object { $_.event -eq "exit" -and $_.reason -eq "SL" }).Count
    $tpExits = @($events | Where-Object { $_.event -eq "exit" -and $_.reason -eq "TP" }).Count
    $results += [pscustomobject]@{
        variant = $variant.Name
        preset = $presetFile
        trades = [int]$summary.closed_trades
        expectancy_r = [double]$summary.expectancy_r
        pf = [double]$summary.profit_factor
        max_dd_percent = [double]$summary.max_dd_percent
        max_losses = [int]$summary.max_consecutive_losses
        net_money = [double]$summary.net_money
        stops = $stopCount
        margin_rejects = $marginRejects
        tp_exits = $tpExits
        sl_exits = $slExits
        timeout_exits = $timeoutExits
    }
}
$results | Export-Csv -LiteralPath (Join-Path $PSScriptRoot "final_check_variant_summary.csv") -NoTypeInformation -Encoding UTF8
$results | Format-Table -AutoSize
