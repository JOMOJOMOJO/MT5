param(
    [string]$OutputDir = "reports\backtest\runs\20260623_fxelliott_roadmap_diagnostics"
)

$ErrorActionPreference = "Stop"
$culture = [Globalization.CultureInfo]::InvariantCulture

function Convert-Number {
    param([object]$Value)
    if ($null -eq $Value) { return 0.0 }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return 0.0 }
    if ($text -eq "INF") { return [double]::PositiveInfinity }
    return [double]::Parse(($text -replace ',', '').Trim(), $culture)
}

function Convert-MetricNumber {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $clean = ($Value -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace ',', '' -replace ' ', '').Trim()
    $match = [regex]::Match($clean, '[-+]?\d+(?:\.\d+)?')
    if (-not $match.Success) { return $null }
    return [double]::Parse($match.Value, $culture)
}

function Convert-TradeDate {
    param([string]$Value)
    return [datetime]::ParseExact($Value, "yyyy.MM.dd HH:mm:ss", $culture)
}

function Get-BoldMetricAtLine {
    param(
        [string[]]$Lines,
        [int]$LineNumber
    )
    if ($LineNumber -lt 1 -or $LineNumber -gt $Lines.Count) { return $null }
    $match = [regex]::Match($Lines[$LineNumber - 1], '<b>(.*?)</b>')
    if ($match.Success) { return $match.Groups[1].Value }
    return $null
}

function Get-Mt5Metrics {
    param([string]$Path)
    $lines = Get-Content -Path $Path
    $baseLine = $null
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -like '*<b>100%*') {
            $baseLine = $i + 1
            break
        }
    }
    if (-not $baseLine) { throw "Could not locate MT5 model-quality line in $Path" }

    [pscustomobject]@{
        net_profit = Convert-MetricNumber (Get-BoldMetricAtLine -Lines $lines -LineNumber ($baseLine + 12))
        gross_profit = Convert-MetricNumber (Get-BoldMetricAtLine -Lines $lines -LineNumber ($baseLine + 20))
        balance_max_dd = Convert-MetricNumber (Get-BoldMetricAtLine -Lines $lines -LineNumber ($baseLine + 22))
        equity_max_dd = Convert-MetricNumber (Get-BoldMetricAtLine -Lines $lines -LineNumber ($baseLine + 24))
        gross_loss = Convert-MetricNumber (Get-BoldMetricAtLine -Lines $lines -LineNumber ($baseLine + 28))
        profit_factor = Convert-MetricNumber (Get-BoldMetricAtLine -Lines $lines -LineNumber ($baseLine + 39))
        expected_payoff = Convert-MetricNumber (Get-BoldMetricAtLine -Lines $lines -LineNumber ($baseLine + 41))
        recovery_factor = Convert-MetricNumber (Get-BoldMetricAtLine -Lines $lines -LineNumber ($baseLine + 47))
        total_trades = Convert-MetricNumber (Get-BoldMetricAtLine -Lines $lines -LineNumber ($baseLine + 74))
    }
}

function Get-ElliottSummary {
    param([string]$Path)
    $line = Get-Content -Path $Path | Select-Object -Last 1
    $parts = $line -split ','
    if ($parts.Count -lt 14) { throw "Unexpected summary row in $Path" }
    $tailStart = $parts.Count - 12
    [pscustomobject]@{
        time = $parts[0]
        strategy = $parts[1]
        symbols = ($parts[2..($tailStart - 1)] -join ',')
        signals = $parts[$tailStart]
        orders_sent = $parts[$tailStart + 1]
        orders_failed = $parts[$tailStart + 2]
        blocked = $parts[$tailStart + 3]
        closed_trades = $parts[$tailStart + 4]
        initial_equity = $parts[$tailStart + 5]
        final_equity = $parts[$tailStart + 6]
        peak_equity = $parts[$tailStart + 7]
        daily_stopped = $parts[$tailStart + 8]
        drawdown_stopped = $parts[$tailStart + 9]
        pivot_future_reference_policy = $parts[$tailStart + 10]
        pivot_confirmation_delay_bars = $parts[$tailStart + 11]
    }
}

function Get-SideStats {
    param([object[]]$Rows)
    $rowsArray = @($Rows)
    $count = $rowsArray.Count
    $profits = @($rowsArray | ForEach-Object { Convert-Number $_.net_profit })
    $rValues = @($rowsArray | ForEach-Object { Convert-Number $_.result_r })
    $wins = @($profits | Where-Object { $_ -gt 0 }).Count
    $grossProfit = ($profits | Where-Object { $_ -gt 0 } | Measure-Object -Sum).Sum
    $grossLoss = ($profits | Where-Object { $_ -lt 0 } | Measure-Object -Sum).Sum
    $netProfit = ($profits | Measure-Object -Sum).Sum
    $sumWinR = ($rValues | Where-Object { $_ -gt 0 } | Measure-Object -Sum).Sum
    $sumLossR = ($rValues | Where-Object { $_ -lt 0 } | Measure-Object -Sum).Sum
    $sumR = ($rValues | Measure-Object -Sum).Sum
    if ($null -eq $grossProfit) { $grossProfit = 0.0 }
    if ($null -eq $grossLoss) { $grossLoss = 0.0 }
    if ($null -eq $netProfit) { $netProfit = 0.0 }
    if ($null -eq $sumWinR) { $sumWinR = 0.0 }
    if ($null -eq $sumLossR) { $sumLossR = 0.0 }
    if ($null -eq $sumR) { $sumR = 0.0 }
    [pscustomobject]@{
        trades = $count
        win_rate = if ($count -gt 0) { $wins / $count } else { 0.0 }
        net_profit = $netProfit
        gross_profit = $grossProfit
        gross_loss = $grossLoss
        profit_factor_from_trades = if ($grossLoss -lt 0) { $grossProfit / [math]::Abs($grossLoss) } elseif ($grossProfit -gt 0) { [double]::PositiveInfinity } else { 0.0 }
        sum_r = $sumR
        avg_r = if ($count -gt 0) { $sumR / $count } else { 0.0 }
        r_profit_factor = if ($sumLossR -lt 0) { $sumWinR / [math]::Abs($sumLossR) } elseif ($sumWinR -gt 0) { [double]::PositiveInfinity } else { 0.0 }
    }
}

function Get-RMetricStats {
    param([object[]]$Rows)
    $rValues = @($Rows | ForEach-Object { Convert-Number $_.result_r } | Sort-Object)
    $count = $rValues.Count
    if ($count -eq 0) {
        return [pscustomobject]@{ trades = 0; sum_r = 0.0; avg_r = 0.0; median_r = 0.0; min_r = 0.0; max_r = 0.0; stdev_r = 0.0; p25_r = 0.0; p75_r = 0.0; avg_win_r = 0.0; avg_loss_r = 0.0; payoff_r = 0.0 }
    }
    $sumR = ($rValues | Measure-Object -Sum).Sum
    $avgR = $sumR / $count
    $variance = (($rValues | ForEach-Object { [math]::Pow(($_ - $avgR), 2) } | Measure-Object -Sum).Sum) / $count
    $wins = @($rValues | Where-Object { $_ -gt 0 })
    $losses = @($rValues | Where-Object { $_ -lt 0 })
    $avgWin = if ($wins.Count -gt 0) { ($wins | Measure-Object -Average).Average } else { 0.0 }
    $avgLoss = if ($losses.Count -gt 0) { ($losses | Measure-Object -Average).Average } else { 0.0 }
    [pscustomobject]@{
        trades = $count
        sum_r = $sumR
        avg_r = $avgR
        median_r = $rValues[[math]::Floor(($count - 1) / 2)]
        min_r = $rValues[0]
        max_r = $rValues[$count - 1]
        stdev_r = [math]::Sqrt($variance)
        p25_r = $rValues[[math]::Floor(($count - 1) * 0.25)]
        p75_r = $rValues[[math]::Floor(($count - 1) * 0.75)]
        avg_win_r = $avgWin
        avg_loss_r = $avgLoss
        payoff_r = if ($avgLoss -lt 0) { $avgWin / [math]::Abs($avgLoss) } else { 0.0 }
    }
}

function New-GroupStatsObject {
    param(
        [string]$Mode,
        [string]$KeyName,
        [string]$KeyValue,
        [object[]]$Rows,
        [string]$SetupType = ""
    )
    $stats = Get-SideStats -Rows $Rows
    $obj = [ordered]@{ mode = $Mode }
    if ($SetupType -ne "") { $obj["setup_type"] = $SetupType }
    $obj[$KeyName] = $KeyValue
    $obj["trades"] = $stats.trades
    $obj["win_rate"] = $stats.win_rate
    $obj["net_profit"] = $stats.net_profit
    $obj["gross_profit"] = $stats.gross_profit
    $obj["gross_loss"] = $stats.gross_loss
    $obj["profit_factor_from_trades"] = $stats.profit_factor_from_trades
    $obj["sum_r"] = $stats.sum_r
    $obj["avg_r"] = $stats.avg_r
    $obj["r_profit_factor"] = $stats.r_profit_factor
    [pscustomobject]$obj
}

function Test-DirectionBalance {
    param([object[]]$Rows)
    $groups = @($Rows | Group-Object direction)
    if ($groups.Count -lt 2) { return $false }
    foreach ($group in $groups) {
        $stats = Get-SideStats -Rows $group.Group
        if ($stats.trades -lt 30) { return $false }
        if ($stats.avg_r -lt -0.08) { return $false }
        if ($stats.profit_factor_from_trades -lt 0.80) { return $false }
    }
    return $true
}

function Get-BoughtCurrency {
    param([object]$Row)
    if ($Row.direction -eq "LONG") { return $Row.base_currency }
    return $Row.quote_currency
}

function Test-CurrencyConcentration {
    param([object[]]$Rows)
    $stats = Get-SideStats -Rows $Rows
    if ($stats.net_profit -le 0) { return $false }
    $exposures = foreach ($row in $Rows) {
        [pscustomobject]@{
            currency = Get-BoughtCurrency -Row $row
            net_profit = Convert-Number $row.net_profit
            result_r = Convert-Number $row.result_r
        }
    }
    $currencyStats = foreach ($group in ($exposures | Group-Object currency)) {
        $statsForCurrency = Get-SideStats -Rows $group.Group
        [pscustomobject]@{ currency = $group.Name; net_profit = $statsForCurrency.net_profit }
    }
    $positive = @($currencyStats | Where-Object { $_.net_profit -gt 0 })
    if ($positive.Count -lt 2) { return $false }
    $maxProfit = ($positive | Measure-Object -Property net_profit -Maximum).Maximum
    return ($maxProfit / $stats.net_profit) -lt 0.75
}

function Get-RoomBucket {
    param([object]$Row)
    $value = Convert-Number $Row.room_to_2r
    if ($value -lt 1.0) { return "<1r" }
    if ($value -lt 2.0) { return "1_to_2r" }
    return ">=2r"
}

function Get-FibConfluence {
    param([object]$Row)
    $zone = [string]$Row.fib_zone
    return $zone -in @("wave2_50_618", "wave4_382", "abc_50_786")
}

function Get-DivergencePresence {
    param([object]$Row)
    return ([string]$Row.divergence_type) -ne "none"
}

function Add-GroupedStats {
    param(
        [System.Collections.Generic.List[object]]$Target,
        [object[]]$Rows,
        [string]$Mode,
        [string]$PropertyName,
        [string]$OutputKeyName
    )
    foreach ($group in ($Rows | Group-Object $PropertyName)) {
        $Target.Add((New-GroupStatsObject -Mode $Mode -KeyName $OutputKeyName -KeyValue $group.Name -Rows $group.Group))
    }
}

function Add-SetupGroupedStats {
    param(
        [System.Collections.Generic.List[object]]$Target,
        [object[]]$Rows,
        [string]$Mode,
        [scriptblock]$KeyScript,
        [string]$OutputKeyName
    )
    foreach ($setupGroup in ($Rows | Group-Object setup_type)) {
        foreach ($group in ($setupGroup.Group | Group-Object $KeyScript)) {
            $Target.Add((New-GroupStatsObject -Mode $Mode -SetupType $setupGroup.Name -KeyName $OutputKeyName -KeyValue ([string]$group.Name) -Rows $group.Group))
        }
    }
}

$scenarios = @(
    @{ scenario = "A"; mode = "wave3_start_pullback_only"; run_dir = "reports\backtest\runs\20260623_fxelliott_wave3_start_pullback_2025"; setup_only = $true },
    @{ scenario = "B"; mode = "wave4_continuation_only"; run_dir = "reports\backtest\runs\20260623_fxelliott_wave4_continuation_2025"; setup_only = $true },
    @{ scenario = "C"; mode = "abc_completion_reentry_only"; run_dir = "reports\backtest\runs\20260623_fxelliott_abc_completion_reentry_2025"; setup_only = $true },
    @{ scenario = "D"; mode = "combined_roadmap_triggers"; run_dir = "reports\backtest\runs\20260623_fxelliott_combined_2025"; setup_only = $false }
)

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$comparison = New-Object System.Collections.Generic.List[object]
$allTrades = New-Object System.Collections.Generic.List[object]
$yearly = New-Object System.Collections.Generic.List[object]
$monthly = New-Object System.Collections.Generic.List[object]
$symbolBreakdown = New-Object System.Collections.Generic.List[object]
$directionBreakdown = New-Object System.Collections.Generic.List[object]
$waveStageBreakdown = New-Object System.Collections.Generic.List[object]
$setupTypeBreakdown = New-Object System.Collections.Generic.List[object]
$fibZoneBreakdown = New-Object System.Collections.Generic.List[object]
$divergenceBreakdown = New-Object System.Collections.Generic.List[object]
$failureBreakdown = New-Object System.Collections.Generic.List[object]
$m15Breakdown = New-Object System.Collections.Generic.List[object]
$wave3BreakBreakdown = New-Object System.Collections.Generic.List[object]
$roomBreakdown = New-Object System.Collections.Generic.List[object]
$fibFilterBreakdown = New-Object System.Collections.Generic.List[object]
$divergenceFilterBreakdown = New-Object System.Collections.Generic.List[object]
$signalWaveStageBreakdown = New-Object System.Collections.Generic.List[object]
$signalEventBreakdown = New-Object System.Collections.Generic.List[object]
$rMetrics = New-Object System.Collections.Generic.List[object]

foreach ($scenario in $scenarios) {
    $rows = @(Import-Csv (Join-Path $scenario.run_dir "trades.csv"))
    $signals = @(Import-Csv (Join-Path $scenario.run_dir "signals.csv"))
    $summary = Get-ElliottSummary -Path (Join-Path $scenario.run_dir "summary.csv")
    $metrics = Get-Mt5Metrics -Path (Join-Path $scenario.run_dir "report.html")
    $tradeStats = Get-SideStats -Rows $rows
    $directionOk = Test-DirectionBalance -Rows $rows
    $currencyOk = Test-CurrencyConcentration -Rows $rows
    $passedTradeCount = [int]$summary.closed_trades -ge 200
    $passedPf = $metrics.profit_factor -ge 1.05
    $passedAvgR = $tradeStats.avg_r -gt 0
    $passedNet = $metrics.net_profit -gt 0
    $passedDdStop = $summary.drawdown_stopped -ne "true"
    $singleSetupCandidate = $passedTradeCount -and $passedPf -and $passedAvgR -and $passedNet -and $passedDdStop
    $combinedGate = $singleSetupCandidate -and $directionOk -and $currencyOk

    $failed = New-Object System.Collections.Generic.List[string]
    if (-not $passedTradeCount) { $failed.Add("trades_lt_200") }
    if (-not $passedPf) { $failed.Add("pf_lt_1.05") }
    if (-not $passedAvgR) { $failed.Add("avg_r_le_0") }
    if (-not $passedNet) { $failed.Add("net_le_0") }
    if (-not $passedDdStop) { $failed.Add("dd_stopped") }
    if (-not $scenario.setup_only) {
        if (-not $directionOk) { $failed.Add("direction_balance_failed") }
        if (-not $currencyOk) { $failed.Add("currency_concentration_or_negative_net") }
    }

    foreach ($row in $rows) {
        $obj = [ordered]@{ scenario = $scenario.scenario; mode = $scenario.mode }
        foreach ($prop in $row.PSObject.Properties) { $obj[$prop.Name] = $prop.Value }
        $allTrades.Add([pscustomobject]$obj)
    }

    foreach ($group in ($rows | Group-Object { (Convert-TradeDate $_.entry_time).ToString("yyyy", $culture) })) {
        $yearly.Add((New-GroupStatsObject -Mode $scenario.mode -KeyName "year" -KeyValue $group.Name -Rows $group.Group))
    }
    foreach ($group in ($rows | Group-Object { (Convert-TradeDate $_.entry_time).ToString("yyyy-MM", $culture) })) {
        $monthly.Add((New-GroupStatsObject -Mode $scenario.mode -KeyName "month" -KeyValue $group.Name -Rows $group.Group))
    }
    Add-GroupedStats -Target $symbolBreakdown -Rows $rows -Mode $scenario.mode -PropertyName "symbol" -OutputKeyName "symbol"
    Add-GroupedStats -Target $directionBreakdown -Rows $rows -Mode $scenario.mode -PropertyName "direction" -OutputKeyName "direction"
    Add-GroupedStats -Target $waveStageBreakdown -Rows $rows -Mode $scenario.mode -PropertyName "wave_stage" -OutputKeyName "wave_stage"
    Add-GroupedStats -Target $setupTypeBreakdown -Rows $rows -Mode $scenario.mode -PropertyName "setup_type" -OutputKeyName "setup_type"
    Add-GroupedStats -Target $fibZoneBreakdown -Rows $rows -Mode $scenario.mode -PropertyName "fib_zone" -OutputKeyName "fib_zone"
    Add-GroupedStats -Target $divergenceBreakdown -Rows $rows -Mode $scenario.mode -PropertyName "divergence_type" -OutputKeyName "divergence_type"
    Add-GroupedStats -Target $failureBreakdown -Rows $rows -Mode $scenario.mode -PropertyName "failure_type" -OutputKeyName "failure_type"
    Add-GroupedStats -Target $m15Breakdown -Rows $rows -Mode $scenario.mode -PropertyName "m15_confirmation_type" -OutputKeyName "m15_confirmation_type"
    Add-SetupGroupedStats -Target $wave3BreakBreakdown -Rows $rows -Mode $scenario.mode -KeyScript { $_.wave3_break_confirmed } -OutputKeyName "wave3_break_confirmed"
    Add-SetupGroupedStats -Target $roomBreakdown -Rows $rows -Mode $scenario.mode -KeyScript { Get-RoomBucket -Row $_ } -OutputKeyName "room_to_2r_bucket"
    Add-SetupGroupedStats -Target $fibFilterBreakdown -Rows $rows -Mode $scenario.mode -KeyScript { Get-FibConfluence -Row $_ } -OutputKeyName "fib_confluence"
    Add-SetupGroupedStats -Target $divergenceFilterBreakdown -Rows $rows -Mode $scenario.mode -KeyScript { Get-DivergencePresence -Row $_ } -OutputKeyName "divergence_present"

    foreach ($group in ($signals | Group-Object wave_stage,event)) {
        $parts = $group.Name -split ', '
        $signalWaveStageBreakdown.Add([pscustomobject]@{
            mode = $scenario.mode
            wave_stage = $parts[0]
            event = $parts[1]
            count = $group.Count
        })
    }
    foreach ($group in ($signals | Group-Object event)) {
        $signalEventBreakdown.Add([pscustomobject]@{
            mode = $scenario.mode
            event = $group.Name
            count = $group.Count
        })
    }

    $rm = Get-RMetricStats -Rows $rows
    $rMetrics.Add([pscustomobject]@{
        scenario = $scenario.scenario
        mode = $scenario.mode
        trades = $rm.trades
        sum_r = $rm.sum_r
        avg_r = $rm.avg_r
        median_r = $rm.median_r
        min_r = $rm.min_r
        max_r = $rm.max_r
        stdev_r = $rm.stdev_r
        p25_r = $rm.p25_r
        p75_r = $rm.p75_r
        avg_win_r = $rm.avg_win_r
        avg_loss_r = $rm.avg_loss_r
        payoff_r = $rm.payoff_r
    })

    $comparison.Add([pscustomobject]@{
        scenario = $scenario.scenario
        mode = $scenario.mode
        signals = [int]$summary.signals
        diagnostic_signals = @($signals | Where-Object { $_.event -eq "diagnostic" }).Count
        wave5_exhaustion_diagnostics = @($signals | Where-Object { $_.wave_stage -eq "possible_wave5_exhaustion" }).Count
        orders_sent = [int]$summary.orders_sent
        orders_failed = [int]$summary.orders_failed
        blocked = [int]$summary.blocked
        closed_trades = [int]$summary.closed_trades
        mt5_total_trades = [int]$metrics.total_trades
        net_profit = $metrics.net_profit
        gross_profit = $metrics.gross_profit
        gross_loss = $metrics.gross_loss
        profit_factor = $metrics.profit_factor
        expected_payoff = $metrics.expected_payoff
        balance_max_dd = $metrics.balance_max_dd
        equity_max_dd = $metrics.equity_max_dd
        recovery_factor = $metrics.recovery_factor
        avg_r = $tradeStats.avg_r
        r_profit_factor = $tradeStats.r_profit_factor
        win_rate_from_trades = $tradeStats.win_rate
        final_equity = Convert-Number $summary.final_equity
        peak_equity = Convert-Number $summary.peak_equity
        daily_stopped = $summary.daily_stopped
        drawdown_stopped = $summary.drawdown_stopped
        pivot_future_reference_policy = $summary.pivot_future_reference_policy
        pivot_confirmation_delay_bars = [int]$summary.pivot_confirmation_delay_bars
        single_setup_candidate_gate = $singleSetupCandidate
        passed_trade_count = $passedTradeCount
        passed_pf_floor = $passedPf
        passed_avg_r = $passedAvgR
        passed_net = $passedNet
        passed_dd_stop = $passedDdStop
        passed_direction_balance = $directionOk
        passed_currency_concentration = $currencyOk
        passed_2025_shallow_gate = if ($scenario.setup_only) { $singleSetupCandidate } else { $combinedGate }
        promoted_to_3y_oos = $false
        failed_conditions = ($failed -join ';')
    })
}

$comparison | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "comparison.csv")
$allTrades | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "trades_all_scenarios.csv")
$yearly | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "yearly_breakdown.csv")
$monthly | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "monthly_breakdown.csv")
$symbolBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "symbol_breakdown.csv")
$directionBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "direction_breakdown.csv")
$waveStageBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "wave_stage_breakdown.csv")
$setupTypeBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "setup_type_breakdown.csv")
$fibZoneBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "fib_zone_breakdown.csv")
$divergenceBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "divergence_breakdown.csv")
$failureBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "failure_type_breakdown.csv")
$m15Breakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "m15_confirmation_breakdown.csv")
$wave3BreakBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "wave3_break_confirmed_breakdown.csv")
$roomBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "room_to_2r_breakdown.csv")
$fibFilterBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "fib_confluence_filter_breakdown.csv")
$divergenceFilterBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "divergence_filter_breakdown.csv")
$signalWaveStageBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "signal_wave_stage_breakdown.csv")
$signalEventBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "signal_event_breakdown.csv")
$rMetrics | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "r_metrics.csv")
Copy-Item -LiteralPath "reports\compile\ExpectedValue_MultiCurrency_FXElliottWaveRoadmapTrader_compile.txt" -Destination (Join-Path $OutputDir "compile.txt") -Force

$comparisonRows = @($comparison.ToArray())
$setupTypeRows = @($setupTypeBreakdown.ToArray())
$wave3BreakRows = @($wave3BreakBreakdown.ToArray())
$fibFilterRows = @($fibFilterBreakdown.ToArray())
$divergenceFilterRows = @($divergenceFilterBreakdown.ToArray())
$m15Rows = @($m15Breakdown.ToArray())
$failureRows = @($failureBreakdown.ToArray())
$bestSetup = @($setupTypeRows | Sort-Object avg_r -Descending | Select-Object -First 1)
$combined = $comparisonRows | Where-Object { $_.mode -eq "combined_roadmap_triggers" } | Select-Object -First 1
$combinedWave4 = $setupTypeRows | Where-Object { $_.mode -eq "combined_roadmap_triggers" -and $_.setup_type -eq "wave4_continuation" } | Select-Object -First 1
$combinedAbc = $setupTypeRows | Where-Object { $_.mode -eq "combined_roadmap_triggers" -and $_.setup_type -eq "abc_completion_reentry" } | Select-Object -First 1
$standaloneWave4 = $setupTypeRows | Where-Object { $_.mode -eq "wave4_continuation_only" } | Select-Object -First 1
$standaloneAbc = $setupTypeRows | Where-Object { $_.mode -eq "abc_completion_reentry_only" } | Select-Object -First 1
$wave3Confirmed = @($wave3BreakRows | Where-Object { $_.setup_type -eq "wave3_start_pullback" -and $_.wave3_break_confirmed -eq "true" } | Sort-Object mode | Select-Object -First 1)
$wave3Unconfirmed = @($wave3BreakRows | Where-Object { $_.setup_type -eq "wave3_start_pullback" -and $_.wave3_break_confirmed -eq "false" } | Sort-Object mode | Select-Object -First 1)
$fibTrue = @($fibFilterRows | Where-Object { $_.fib_confluence -eq "True" } | Sort-Object avg_r -Descending | Select-Object -First 1)
$fibFalse = @($fibFilterRows | Where-Object { $_.fib_confluence -eq "False" } | Sort-Object avg_r -Descending | Select-Object -First 1)
$divTrue = @($divergenceFilterRows | Where-Object { $_.divergence_present -eq "True" } | Sort-Object avg_r -Descending | Select-Object -First 1)
$divFalse = @($divergenceFilterRows | Where-Object { $_.divergence_present -eq "False" } | Sort-Object avg_r -Descending | Select-Object -First 1)
$bestM15 = @($m15Rows | Sort-Object avg_r -Descending | Select-Object -First 1)
$worstM15 = @($m15Rows | Sort-Object avg_r | Select-Object -First 1)
$largestFailure = @($failureRows | Sort-Object net_profit | Select-Object -First 1)
$wave5Count = if ($combined) { $combined.wave5_exhaustion_diagnostics } else { 0 }

$summaryLines = New-Object System.Collections.Generic.List[string]
$summaryLines.Add("# FX Elliott Wave Roadmap Diagnostics")
$summaryLines.Add("")
$summaryLines.Add("## Implementation")
$summaryLines.Add("- Elliott Wave was implemented as a roadmap label system, not as strict wave counting.")
$summaryLines.Add("- H1/H4 pivots use confirmed closed bars only. With InpSwingDepth=3, a pivot is usable only after 3 right-side closed bars. ZigZag repaint values are not used.")
$summaryLines.Add("- CSV includes pivot_confirmation_delay_bars, entry_delay_from_pivot, pivot_time, and pivot_confirmed_time. No future high/low is used at entry decision time.")
$summaryLines.Add("- Symbols: USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD. No XAUUSD, symbol exclusion, direction-only gate, or Friday stop was used.")
$summaryLines.Add("")
$summaryLines.Add("## 2025 Shallow Gate")
foreach ($row in $comparisonRows) {
    $summaryLines.Add(("- {0}: trades={1}, PF={2:n2}, avg_R={3:n4}, net={4:n2}, DD_stop={5}, passed={6}, failed={7}" -f $row.mode, $row.closed_trades, $row.profit_factor, $row.avg_r, $row.net_profit, $row.drawdown_stopped, $row.passed_2025_shallow_gate, $row.failed_conditions))
}
$summaryLines.Add("")
$summaryLines.Add("## Diagnostics")
if ($bestSetup) {
    $summaryLines.Add(("- Most promising setup by avg_R in 2025 diagnostics: {0} / {1}, trades={2}, avg_R={3:n4}, PF_from_trades={4:n2}." -f $bestSetup.mode, $bestSetup.setup_type, $bestSetup.trades, $bestSetup.avg_r, $bestSetup.profit_factor_from_trades))
}
if ($wave3Confirmed -and $wave3Unconfirmed) {
    $summaryLines.Add(("- wave3_break_confirmed=true avg_R={0:n4}; false avg_R={1:n4}. If false is materially worse, wave3_start is too early." -f $wave3Confirmed.avg_r, $wave3Unconfirmed.avg_r))
}
if ($combinedWave4 -and $standaloneWave4) {
    $summaryLines.Add(("- wave4_continuation showed chase risk rather than continuation edge: standalone avg_R={0:n4}, combined wave4 avg_R={1:n4}." -f $standaloneWave4.avg_r, $combinedWave4.avg_r))
}
if ($combinedAbc -and $standaloneAbc) {
    $summaryLines.Add(("- abc_completion was the least bad combined component but still not a deployment edge: combined avg_R={0:n4} on {1} trades; standalone avg_R={2:n4} on {3} trades." -f $combinedAbc.avg_r, $combinedAbc.trades, $standaloneAbc.avg_r, $standaloneAbc.trades))
}
$summaryLines.Add(("- wave5 exhaustion chase avoidance diagnostics recorded: {0} signal rows in combined_roadmap_triggers." -f $wave5Count))
if ($fibTrue -and $fibFalse) {
    $summaryLines.Add(("- Fib confluence best true bucket avg_R={0:n4}; best false bucket avg_R={1:n4}. Use breakdown CSV before treating fib as a hard gate." -f $fibTrue.avg_r, $fibFalse.avg_r))
}
if ($divTrue -and $divFalse) {
    $summaryLines.Add(("- Divergence-present best bucket avg_R={0:n4}; divergence-none best bucket avg_R={1:n4}. Divergence is diagnostic, not optimized as a hard gate." -f $divTrue.avg_r, $divFalse.avg_r))
}
$summaryLines.Add(("- M15 confirmation type performance: best bucket {0}/{1} avg_R={2:n4}; weakest bucket {3}/{4} avg_R={5:n4}. Full table: m15_confirmation_breakdown.csv." -f $bestM15.mode, $bestM15.m15_confirmation_type, $bestM15.avg_r, $worstM15.mode, $worstM15.m15_confirmation_type, $worstM15.avg_r))
$summaryLines.Add(("- Largest failure bucket: {0}/{1}, trades={2}, net={3:n2}, avg_R={4:n4}." -f $largestFailure.mode, $largestFailure.failure_type, $largestFailure.trades, $largestFailure.net_profit, $largestFailure.avg_r))
$summaryLines.Add("- Failure hot spots are saved in failure_type_breakdown.csv, plus setup/fib/divergence/room/wave3 confirmation breakdowns.")
$summaryLines.Add("")
$summaryLines.Add("## Promotion")
if ($combined -and $combined.passed_2025_shallow_gate -eq $true) {
    $summaryLines.Add("- combined_roadmap_triggers passed the 2025 shallow gate and should be checked with fixed 3-year BT and latest 12-month OOS.")
} else {
    $summaryLines.Add("- No deployment candidate is promoted to 3-year/OOS from this run. The combined candidate failed 2025 shallow gate conditions.")
}
$summaryLines.Add("- Because 2025 shallow gate failed for deployment, no symbol exclusion, direction-only repair, Friday stop, or narrow RSI/MACD/Fib retuning was applied.")
$summaryLines.Add("- Deployable candidate: none from this cycle.")
$summaryLines | Set-Content -Path (Join-Path $OutputDir "summary.md") -Encoding UTF8

Write-Host "Wrote diagnostics to $OutputDir"
