param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
)

$ErrorActionPreference = "Stop"
$portable = "C:\Users\windows\AppData\Local\CodexMT5BucketLab"
$terminal = Join-Path $portable "terminal64.exe"
$basePreset = Join-Path $RepoRoot "reports\presets\ExpectedValue_LongOnly_BucketLab_v2_3_second_entry_quality_2025.set"
$common = "C:\Users\windows\AppData\Roaming\MetaQuotes\Terminal\Common\Files"
$presetTarget = Join-Path $portable "MQL5\Profiles\Tester"

$variants = @(
    @{Name="f5"; Label="v2_4_h10_r115_cd2"; Hold="10"; R="1.15"; Cool="2"; Open="2"; Risk="5.0"; Magic="2026052125"},
    @{Name="f6"; Label="v2_4_h10_r135_cd2"; Hold="10"; R="1.35"; Cool="2"; Open="2"; Risk="5.0"; Magic="2026052126"},
    @{Name="f7"; Label="v2_4_h12_r135_cd3"; Hold="12"; R="1.35"; Cool="3"; Open="2"; Risk="5.0"; Magic="2026052127"}
)

function Set-PresetValue {
    param([System.Collections.Generic.List[string]]$Lines, [string]$Key, [string]$Value)
    for($i = 0; $i -lt $Lines.Count; $i++) {
        if($Lines[$i] -match ("^" + [regex]::Escape($Key) + "=")) {
            $parts = $Lines[$i] -split "\|\|"
            $parts[0] = "$Key=$Value"
            if($parts.Count -gt 1) { $parts[1] = $Value }
            $Lines[$i] = ($parts -join "||")
            return
        }
    }
}

$results = @()
foreach($variant in $variants) {
    $presetFile = "ExpectedValue_LongOnly_BucketLab_$($variant.Name)_2025.set"
    $presetPath = Join-Path $RepoRoot "reports\presets\$presetFile"
    $lines = [System.Collections.Generic.List[string]](Get-Content -LiteralPath $basePreset)
    Set-PresetValue $lines "InpMagicNumber" $variant.Magic
    Set-PresetValue $lines "InpMaxHoldBars" $variant.Hold
    Set-PresetValue $lines "InpTargetRMultiple" $variant.R
    Set-PresetValue $lines "InpCooldownBars" $variant.Cool
    Set-PresetValue $lines "InpMaxOpenPositions" $variant.Open
    Set-PresetValue $lines "InpMaxTotalOpenRiskPercent" $variant.Risk
    Set-PresetValue $lines "InpPresetName" "ExpectedValue_LongOnly_BucketLab_$($variant.Label)_2025"
    Set-PresetValue $lines "InpEventLogFileName" "mt5_company_expected_value_long_bucketlab_$($variant.Name)_2025_events.csv"
    Set-PresetValue $lines "InpSummaryFileName" "mt5_company_expected_value_long_bucketlab_$($variant.Name)_2025_summary.csv"
    Set-PresetValue $lines "InpMonthlySummaryFileName" "mt5_company_expected_value_long_bucketlab_$($variant.Name)_2025_monthly.csv"
    Set-Content -LiteralPath $presetPath -Value $lines -Encoding ASCII
    Copy-Item -LiteralPath $presetPath -Destination (Join-Path $presetTarget $presetFile) -Force

    $variantDir = Join-Path $PSScriptRoot $variant.Name
    New-Item -ItemType Directory -Force -Path $variantDir | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $variantDir "raw") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $variantDir "ini") | Out-Null
    $reportName = "long_bucketlab_$($variant.Name)_2025"
    $iniPath = Join-Path $variantDir "ini\$reportName.ini"
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
    if(-not $process.WaitForExit(240000)) {
        Stop-Process -Id $process.Id -Force
        throw "MT5 backtest timed out: $($variant.Name)"
    }

    Copy-Item -LiteralPath (Join-Path $common "mt5_company_expected_value_long_bucketlab_$($variant.Name)_2025_events.csv") -Destination (Join-Path $variantDir "raw\events.csv") -Force
    Copy-Item -LiteralPath (Join-Path $common "mt5_company_expected_value_long_bucketlab_$($variant.Name)_2025_summary.csv") -Destination (Join-Path $variantDir "raw\summary.csv") -Force
    Copy-Item -LiteralPath (Join-Path $common "mt5_company_expected_value_long_bucketlab_$($variant.Name)_2025_monthly.csv") -Destination (Join-Path $variantDir "raw\monthly.csv") -Force
    $summary = Import-Csv -LiteralPath (Join-Path $variantDir "raw\summary.csv") -Delimiter ";" | Select-Object -Last 1
    $stopCount = @(Import-Csv -LiteralPath (Join-Path $variantDir "raw\events.csv") -Delimiter ";" | Where-Object { $_.event -eq "stop_condition_triggered" }).Count
    $results += [pscustomobject]@{
        variant = $variant.Label
        trades = [int]$summary.closed_trades
        expectancy = [double]$summary.expectancy_r
        pf = [double]$summary.profit_factor
        dd = [double]$summary.max_dd_percent
        losses = [int]$summary.max_consecutive_losses
        stops = $stopCount
        net = [double]$summary.net_money
    }
}

$results | Export-Csv -LiteralPath (Join-Path $PSScriptRoot "fast_exit_probe2_summary.csv") -NoTypeInformation
$results | Sort-Object @{Expression="trades";Descending=$true} | Format-Table -AutoSize
