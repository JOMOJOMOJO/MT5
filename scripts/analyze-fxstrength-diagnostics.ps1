param(
    [string]$OutputDir = "reports\backtest\runs\20260623_fxstrength_diagnostics"
)

$ErrorActionPreference = "Stop"
$culture = [Globalization.CultureInfo]::InvariantCulture

function Convert-MetricNumber {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $clean = ($Value -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace ',', '' -replace ' ', '').Trim()
    $match = [regex]::Match($clean, '[-+]?\d+(?:\.\d+)?')
    if (-not $match.Success) { return $null }
    return [double]::Parse($match.Value, $culture)
}

function Convert-Number {
    param([object]$Value)
    if ($null -eq $Value) { return 0.0 }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return 0.0 }
    if ($text -eq "INF") { return [double]::PositiveInfinity }
    return [double]::Parse(($text -replace ',', '').Trim(), $culture)
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
    $line = $Lines[$LineNumber - 1]
    $match = [regex]::Match($line, '<b>(.*?)</b>')
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
    if (-not $baseLine) {
        throw "Could not locate MT5 model-quality line in $Path"
    }

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

function Get-FxStrengthSummary {
    param([string]$Path)
    $line = Get-Content -Path $Path | Select-Object -Last 1
    $parts = $line -split ','
    if ($parts.Count -lt 12) { throw "Unexpected summary row in $Path" }
    $tailStart = $parts.Count - 10
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
    $rowsArray = @($Rows)
    $rValues = @($rowsArray | ForEach-Object { Convert-Number $_.result_r } | Sort-Object)
    $count = $rValues.Count
    if ($count -eq 0) {
        return [pscustomobject]@{
            trades = 0; sum_r = 0.0; avg_r = 0.0; median_r = 0.0; min_r = 0.0; max_r = 0.0
            stdev_r = 0.0; p25_r = 0.0; p75_r = 0.0; avg_win_r = 0.0; avg_loss_r = 0.0; payoff_r = 0.0
        }
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
        [object[]]$Rows
    )
    $stats = Get-SideStats -Rows $Rows
    $obj = [ordered]@{
        mode = $Mode
    }
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

function Get-SoldCurrency {
    param([object]$Row)
    if ($Row.direction -eq "LONG") { return $Row.quote_currency }
    return $Row.base_currency
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
        Get-SideStats -Rows $group.Group | Add-Member -NotePropertyName currency -NotePropertyValue $group.Name -PassThru
    }
    $positive = @($currencyStats | Where-Object { $_.net_profit -gt 0 })
    if ($positive.Count -lt 2) { return $false }
    $maxProfit = ($positive | Measure-Object -Property net_profit -Maximum).Maximum
    return ($maxProfit / $stats.net_profit) -lt 0.75
}

function Get-StrengthDiffBucket {
    param([object]$Row)
    $value = Convert-Number $Row.strength_diff
    if ($value -le -2.0) { return "<=-2.0" }
    if ($value -le -1.5) { return "-2.0_to_-1.5" }
    if ($value -le -1.0) { return "-1.5_to_-1.0" }
    if ($value -lt 0.0) { return "-1.0_to_0" }
    if ($value -lt 1.0) { return "0_to_1.0" }
    if ($value -lt 1.5) { return "1.0_to_1.5" }
    if ($value -lt 2.0) { return "1.5_to_2.0" }
    return ">=2.0"
}

$scenarios = @(
    @{ scenario = "A"; mode = "currency_strength_momentum"; run_dir = "reports\backtest\runs\20260623_fxstrength_momentum_2025" },
    @{ scenario = "B"; mode = "currency_strength_pullback"; run_dir = "reports\backtest\runs\20260623_fxstrength_pullback_2025" },
    @{ scenario = "C"; mode = "currency_strength_reversal_avoid"; run_dir = "reports\backtest\runs\20260623_fxstrength_reversal_avoid_2025" },
    @{ scenario = "D"; mode = "currency_strength_momentum_room_to_2r"; run_dir = "reports\backtest\runs\20260623_fxstrength_momentum_room2r_2025" },
    @{ scenario = "E"; mode = "currency_strength_pullback_room_to_2r"; run_dir = "reports\backtest\runs\20260623_fxstrength_pullback_room2r_2025" }
)

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$comparison = New-Object System.Collections.Generic.List[object]
$allTrades = New-Object System.Collections.Generic.List[object]
$yearly = New-Object System.Collections.Generic.List[object]
$monthly = New-Object System.Collections.Generic.List[object]
$symbolBreakdown = New-Object System.Collections.Generic.List[object]
$directionBreakdown = New-Object System.Collections.Generic.List[object]
$currencyBreakdown = New-Object System.Collections.Generic.List[object]
$strengthDiffBreakdown = New-Object System.Collections.Generic.List[object]
$failureBreakdown = New-Object System.Collections.Generic.List[object]
$rMetrics = New-Object System.Collections.Generic.List[object]

foreach ($scenario in $scenarios) {
    $rows = @(Import-Csv (Join-Path $scenario.run_dir "trades.csv"))
    $summary = Get-FxStrengthSummary -Path (Join-Path $scenario.run_dir "summary.csv")
    $metrics = Get-Mt5Metrics -Path (Join-Path $scenario.run_dir "report.html")
    $tradeStats = Get-SideStats -Rows $rows
    $directionOk = Test-DirectionBalance -Rows $rows
    $currencyOk = Test-CurrencyConcentration -Rows $rows
    $passedTradeCount = [int]$summary.closed_trades -ge 200
    $passedPf = $metrics.profit_factor -ge 1.05
    $passedAvgR = $tradeStats.avg_r -gt 0
    $passedNet = $metrics.net_profit -gt 0
    $passedDdStop = $summary.drawdown_stopped -ne "true"
    $passedGate = $passedTradeCount -and $passedPf -and $passedAvgR -and $passedNet -and $passedDdStop -and $directionOk -and $currencyOk

    $failed = New-Object System.Collections.Generic.List[string]
    if (-not $passedTradeCount) { $failed.Add("trades_lt_200") }
    if (-not $passedPf) { $failed.Add("pf_lt_1.05") }
    if (-not $passedAvgR) { $failed.Add("avg_r_le_0") }
    if (-not $passedNet) { $failed.Add("net_le_0") }
    if (-not $passedDdStop) { $failed.Add("dd_stopped") }
    if (-not $directionOk) { $failed.Add("direction_balance_failed") }
    if (-not $currencyOk) { $failed.Add("currency_concentration_or_negative_net") }

    foreach ($row in $rows) {
        $obj = [ordered]@{
            scenario = $scenario.scenario
            mode = $scenario.mode
        }
        foreach ($prop in $row.PSObject.Properties) {
            $obj[$prop.Name] = $prop.Value
        }
        $allTrades.Add([pscustomobject]$obj)
    }

    foreach ($group in ($rows | Group-Object { (Convert-TradeDate $_.entry_time).ToString("yyyy", $culture) })) {
        $yearly.Add((New-GroupStatsObject -Mode $scenario.mode -KeyName "year" -KeyValue $group.Name -Rows $group.Group))
    }
    foreach ($group in ($rows | Group-Object { (Convert-TradeDate $_.entry_time).ToString("yyyy-MM", $culture) })) {
        $monthly.Add((New-GroupStatsObject -Mode $scenario.mode -KeyName "month" -KeyValue $group.Name -Rows $group.Group))
    }
    foreach ($group in ($rows | Group-Object symbol)) {
        $symbolBreakdown.Add((New-GroupStatsObject -Mode $scenario.mode -KeyName "symbol" -KeyValue $group.Name -Rows $group.Group))
    }
    foreach ($group in ($rows | Group-Object direction)) {
        $directionBreakdown.Add((New-GroupStatsObject -Mode $scenario.mode -KeyName "direction" -KeyValue $group.Name -Rows $group.Group))
    }
    foreach ($group in ($rows | Group-Object failure_type)) {
        $failureBreakdown.Add((New-GroupStatsObject -Mode $scenario.mode -KeyName "failure_type" -KeyValue $group.Name -Rows $group.Group))
    }
    foreach ($group in ($rows | Group-Object { Get-StrengthDiffBucket -Row $_ })) {
        $strengthDiffBreakdown.Add((New-GroupStatsObject -Mode $scenario.mode -KeyName "strength_diff_bucket" -KeyValue $group.Name -Rows $group.Group))
    }

    $exposures = foreach ($row in $rows) {
        $boughtStrength = if ($row.direction -eq "LONG") { Convert-Number $row.base_strength } else { Convert-Number $row.quote_strength }
        $soldStrength = if ($row.direction -eq "LONG") { Convert-Number $row.quote_strength } else { Convert-Number $row.base_strength }
        [pscustomobject]@{ role = "bought"; currency = Get-BoughtCurrency -Row $row; strength = $boughtStrength; net_profit = $row.net_profit; result_r = $row.result_r }
        [pscustomobject]@{ role = "sold"; currency = Get-SoldCurrency -Row $row; strength = $soldStrength; net_profit = $row.net_profit; result_r = $row.result_r }
    }
    foreach ($group in ($exposures | Group-Object role,currency)) {
        $stats = Get-SideStats -Rows $group.Group
        $currencyBreakdown.Add([pscustomobject]@{
            mode = $scenario.mode
            role = ($group.Name -split ', ')[0]
            currency = ($group.Name -split ', ')[1]
            trades = $stats.trades
            avg_strength = (($group.Group | ForEach-Object { Convert-Number $_.strength } | Measure-Object -Average).Average)
            win_rate = $stats.win_rate
            net_profit = $stats.net_profit
            profit_factor_from_trades = $stats.profit_factor_from_trades
            sum_r = $stats.sum_r
            avg_r = $stats.avg_r
            r_profit_factor = $stats.r_profit_factor
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
        passed_trade_count = $passedTradeCount
        passed_pf_floor = $passedPf
        passed_avg_r = $passedAvgR
        passed_net = $passedNet
        passed_dd_stop = $passedDdStop
        passed_direction_balance = $directionOk
        passed_currency_concentration = $currencyOk
        passed_2025_shallow_gate = $passedGate
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
$currencyBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "currency_strength_breakdown.csv")
$strengthDiffBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "strength_diff_bucket.csv")
$failureBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "failure_type_breakdown.csv")
$rMetrics | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "r_metrics.csv")
Copy-Item -LiteralPath "reports\compile\ExpectedValue_MultiCurrency_FXCurrencyStrengthTrader_compile.txt" -Destination (Join-Path $OutputDir "compile.txt") -Force

Write-Host "Wrote diagnostics to $OutputDir"
