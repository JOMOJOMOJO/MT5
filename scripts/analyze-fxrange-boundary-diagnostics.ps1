param(
    [string]$OutputDir = "reports\backtest\runs\20260623_fxrange_boundary_diagnostics"
)

$ErrorActionPreference = "Stop"

function Convert-MetricNumber {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $clean = ($Value -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace ',', '' -replace ' ', '').Trim()
    $match = [regex]::Match($clean, '[-+]?\d+(?:\.\d+)?')
    if (-not $match.Success) { return $null }
    return [double]::Parse($match.Value, [Globalization.CultureInfo]::InvariantCulture)
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

function Get-FxBasketSummary {
    param([string]$Path)
    $line = Get-Content $Path | Select-Object -Last 1
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
    $wins = @($rowsArray | Where-Object { [double]$_.net_profit -gt 0 }).Count
    $grossProfit = ($rowsArray | ForEach-Object { [double]$_.net_profit } | Where-Object { $_ -gt 0 } | Measure-Object -Sum).Sum
    $grossLoss = ($rowsArray | ForEach-Object { [double]$_.net_profit } | Where-Object { $_ -lt 0 } | Measure-Object -Sum).Sum
    $netProfit = ($rowsArray | ForEach-Object { [double]$_.net_profit } | Measure-Object -Sum).Sum
    $sumWinR = ($rowsArray | ForEach-Object { [double]$_.result_r } | Where-Object { $_ -gt 0 } | Measure-Object -Sum).Sum
    $sumLossR = ($rowsArray | ForEach-Object { [double]$_.result_r } | Where-Object { $_ -lt 0 } | Measure-Object -Sum).Sum
    $sumR = ($rowsArray | ForEach-Object { [double]$_.result_r } | Measure-Object -Sum).Sum
    [pscustomobject]@{
        trades = $count
        win_rate = if ($count -gt 0) { $wins / $count } else { 0 }
        net_profit = $netProfit
        gross_profit = $grossProfit
        gross_loss = $grossLoss
        profit_factor_from_trades = if ($grossLoss -lt 0) { $grossProfit / [math]::Abs($grossLoss) } elseif ($grossProfit -gt 0) { [double]::PositiveInfinity } else { 0 }
        sum_r = $sumR
        avg_r = if ($count -gt 0) { $sumR / $count } else { 0 }
        r_profit_factor = if ($sumLossR -lt 0) { $sumWinR / [math]::Abs($sumLossR) } elseif ($sumWinR -gt 0) { [double]::PositiveInfinity } else { 0 }
    }
}

function Format-ObjectForCsv {
    param([pscustomobject]$Object)
    foreach ($prop in $Object.PSObject.Properties) {
        if ($prop.Value -is [double] -or $prop.Value -is [float] -or $prop.Value -is [decimal]) {
            if ([double]::IsInfinity([double]$prop.Value)) {
                $prop.Value = "INF"
            } else {
                $prop.Value = ([double]$prop.Value).ToString("0.####", [Globalization.CultureInfo]::InvariantCulture)
            }
        }
    }
    return $Object
}

function Test-DirectionBalance {
    param([object[]]$Rows)
    $groups = $Rows | Group-Object direction
    if (@($groups).Count -lt 2) { return $false }
    foreach ($group in $groups) {
        $stats = Get-SideStats -Rows $group.Group
        if ($stats.trades -lt 30) { return $false }
        if ($stats.avg_r -lt -0.08) { return $false }
        if ($stats.profit_factor_from_trades -lt 0.80) { return $false }
    }
    return $true
}

function Test-SymbolConcentration {
    param([object[]]$Rows)
    $stats = Get-SideStats -Rows $Rows
    if ($stats.net_profit -le 0) { return $false }
    $symbolStats = foreach ($group in ($Rows | Group-Object symbol)) {
        Get-SideStats -Rows $group.Group
    }
    $positive = @($symbolStats | Where-Object { $_.net_profit -gt 0 })
    if ($positive.Count -lt 2) { return $false }
    $maxProfit = ($positive | Measure-Object -Property net_profit -Maximum).Maximum
    return ($maxProfit / $stats.net_profit) -lt 0.75
}

$scenarios = @(
    @{
        mode = "new_range_boundary_reversion_fixedR"
        run_dir = "reports\backtest\runs\20260623_fxrange_boundary_fixedR_2025"
    },
    @{
        mode = "new_range_boundary_reversion_to_mid"
        run_dir = "reports\backtest\runs\20260623_fxrange_boundary_to_mid_2025"
    },
    @{
        mode = "new_range_boundary_reversion_to_mid_with_trend_filter"
        run_dir = "reports\backtest\runs\20260623_fxrange_boundary_to_mid_trend_filter_2025"
    },
    @{
        mode = "new_range_boundary_reversion_to_mid_with_boundary_only"
        run_dir = "reports\backtest\runs\20260623_fxrange_boundary_to_mid_boundary_only_2025"
    }
)

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$comparison = New-Object System.Collections.Generic.List[object]
$allTrades = New-Object System.Collections.Generic.List[object]

$previousComparison = "reports\backtest\runs\20260622_fxbasket_context_trader_2025_diagnostics\comparison.csv"
if (Test-Path $previousComparison) {
    $prev = Import-Csv $previousComparison | Where-Object { $_.mode -eq "range_reversion" } | Select-Object -First 1
    if ($prev) {
        $comparison.Add([pscustomobject]@{
            scenario = "A"
            mode = "previous_range_reversion"
            closed_trades = [int]$prev.closed_trades
            mt5_total_trades = [int]$prev.mt5_total_trades
            net_profit = [double]$prev.net_profit
            gross_profit = [double]$prev.gross_profit
            gross_loss = [double]$prev.gross_loss
            profit_factor = [double]$prev.profit_factor
            expected_payoff = [double]$prev.expected_payoff
            balance_max_dd = [double]$prev.balance_max_dd
            equity_max_dd = [double]$prev.equity_max_dd
            recovery_factor = [double]$prev.recovery_factor
            avg_r = [double]$prev.avg_r
            r_profit_factor = [double]$prev.r_profit_factor
            win_rate_from_trades = [double]$prev.win_rate_from_trades
            final_equity = [double]$prev.final_equity
            peak_equity = [double]$prev.peak_equity
            drawdown_stopped = $prev.drawdown_stopped
            daily_stopped = $prev.daily_stopped
            passed_trade_count = ([int]$prev.closed_trades -ge 200)
            passed_pf_floor = ([double]$prev.profit_factor -ge 1.05)
            passed_avg_r = ([double]$prev.avg_r -gt 0)
            passed_net = ([double]$prev.net_profit -gt 0)
            passed_dd_stop = ($prev.drawdown_stopped -ne "true")
            passed_direction_balance = $false
            passed_symbol_concentration = $false
            passed_2025_shallow_gate = $false
            promoted_to_3y_oos = $false
        })
    }
}

$scenarioIndex = 1
foreach ($scenario in $scenarios) {
    $rows = @(Import-Csv (Join-Path $scenario.run_dir "trades.csv"))
    $summary = Get-FxBasketSummary -Path (Join-Path $scenario.run_dir "summary.csv")
    $reportLines = Get-Content (Join-Path $scenario.run_dir "report.html")
    $tradeStats = Get-SideStats -Rows $rows
    $directionOk = Test-DirectionBalance -Rows $rows
    $symbolOk = Test-SymbolConcentration -Rows $rows
    $mt5TotalTrades = Convert-MetricNumber -Value (Get-BoldMetricAtLine -Lines $reportLines -LineNumber 355)
    $mt5NetProfit = Convert-MetricNumber -Value (Get-BoldMetricAtLine -Lines $reportLines -LineNumber 293)
    $mt5GrossProfit = Convert-MetricNumber -Value (Get-BoldMetricAtLine -Lines $reportLines -LineNumber 301)
    $mt5GrossLoss = Convert-MetricNumber -Value (Get-BoldMetricAtLine -Lines $reportLines -LineNumber 309)
    $mt5ProfitFactor = Convert-MetricNumber -Value (Get-BoldMetricAtLine -Lines $reportLines -LineNumber 320)
    $mt5ExpectedPayoff = Convert-MetricNumber -Value (Get-BoldMetricAtLine -Lines $reportLines -LineNumber 322)
    $mt5BalanceMaxDd = Convert-MetricNumber -Value (Get-BoldMetricAtLine -Lines $reportLines -LineNumber 303)
    $mt5EquityMaxDd = Convert-MetricNumber -Value (Get-BoldMetricAtLine -Lines $reportLines -LineNumber 305)
    $mt5RecoveryFactor = Convert-MetricNumber -Value (Get-BoldMetricAtLine -Lines $reportLines -LineNumber 328)
    $passedTradeCount = [int]$summary.closed_trades -ge 200
    $passedPf = $mt5ProfitFactor -ge 1.05
    $passedAvgR = $tradeStats.avg_r -gt 0
    $passedNet = $mt5NetProfit -gt 0
    $passedDdStop = $summary.drawdown_stopped -ne "true"
    $passedGate = $passedTradeCount -and $passedPf -and $passedAvgR -and $passedNet -and $passedDdStop -and $directionOk -and $symbolOk

    foreach ($row in $rows) {
        $allTrades.Add([pscustomobject]@{
            mode = $scenario.mode
            entry_time = $row.entry_time
            exit_time = $row.exit_time
            symbol = $row.symbol
            direction = $row.direction
            entry_type = $row.entry_type
            range_position = $row.range_position
            regime_type = $row.regime_type
            failure_type = $row.failure_type
            result_r = $row.result_r
            net_profit = $row.net_profit
            volume = $row.volume
            reward_r = $row.reward_r
            holding_bars = $row.holding_bars
            zscore = $row.zscore
            rsi = $row.rsi
            distance_to_range_mid_r = $row.distance_to_range_mid_r
            distance_to_opposite_boundary_r = $row.distance_to_opposite_boundary_r
            room_to_mean = $row.room_to_mean
            room_to_range_mid = $row.room_to_range_mid
            room_to_opposite_boundary = $row.room_to_opposite_boundary
            exit_reason = $row.exit_reason
        })
    }

    $scenarioLetter = @("B", "C", "D", "E")[$scenarioIndex - 1]
    $comparison.Add([pscustomobject]@{
        scenario = $scenarioLetter
        mode = $scenario.mode
        closed_trades = [int]$summary.closed_trades
        mt5_total_trades = $mt5TotalTrades
        net_profit = $mt5NetProfit
        gross_profit = $mt5GrossProfit
        gross_loss = $mt5GrossLoss
        profit_factor = $mt5ProfitFactor
        expected_payoff = $mt5ExpectedPayoff
        balance_max_dd = $mt5BalanceMaxDd
        equity_max_dd = $mt5EquityMaxDd
        recovery_factor = $mt5RecoveryFactor
        avg_r = $tradeStats.avg_r
        r_profit_factor = $tradeStats.r_profit_factor
        win_rate_from_trades = $tradeStats.win_rate
        final_equity = [double]$summary.final_equity
        peak_equity = [double]$summary.peak_equity
        drawdown_stopped = $summary.drawdown_stopped
        daily_stopped = $summary.daily_stopped
        passed_trade_count = $passedTradeCount
        passed_pf_floor = $passedPf
        passed_avg_r = $passedAvgR
        passed_net = $passedNet
        passed_dd_stop = $passedDdStop
        passed_direction_balance = $directionOk
        passed_symbol_concentration = $symbolOk
        passed_2025_shallow_gate = $passedGate
        promoted_to_3y_oos = $false
    })
    $scenarioIndex++
}

$allTrades | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "trades_all_scenarios.csv")
$comparison | ForEach-Object { Format-ObjectForCsv $_ } | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "comparison.csv")

$dateCulture = [Globalization.CultureInfo]::InvariantCulture
$parsedTrades = foreach ($trade in $allTrades) {
    $exit = [datetime]::ParseExact($trade.exit_time, "yyyy.MM.dd HH:mm:ss", $dateCulture)
    [pscustomobject]@{
        mode = $trade.mode
        year = $exit.ToString("yyyy")
        month = $exit.ToString("yyyy-MM")
        symbol = $trade.symbol
        direction = $trade.direction
        regime_type = $trade.regime_type
        range_position = $trade.range_position
        failure_type = $trade.failure_type
        result_r = [double]$trade.result_r
        net_profit = [double]$trade.net_profit
    }
}

foreach ($groupSpec in @(
    @{ name = "yearly_breakdown.csv"; keys = @("mode", "year") },
    @{ name = "monthly_breakdown.csv"; keys = @("mode", "month") },
    @{ name = "symbol_breakdown.csv"; keys = @("mode", "symbol") },
    @{ name = "direction_breakdown.csv"; keys = @("mode", "direction") },
    @{ name = "regime_breakdown.csv"; keys = @("mode", "regime_type") },
    @{ name = "range_position_breakdown.csv"; keys = @("mode", "range_position") },
    @{ name = "failure_type_breakdown.csv"; keys = @("mode", "failure_type") },
    @{ name = "r_metrics.csv"; keys = @("mode") }
)) {
    $outRows = foreach ($group in ($parsedTrades | Group-Object -Property $groupSpec.keys)) {
        $stats = Get-SideStats -Rows $group.Group
        $keyValues = $group.Name -split ', '
        $obj = [ordered]@{}
        for ($i = 0; $i -lt $groupSpec.keys.Count; $i++) {
            $obj[$groupSpec.keys[$i]] = $keyValues[$i]
        }
        $obj["trades"] = $stats.trades
        $obj["win_rate"] = $stats.win_rate
        $obj["net_profit"] = $stats.net_profit
        $obj["profit_factor_from_trades"] = $stats.profit_factor_from_trades
        $obj["sum_r"] = $stats.sum_r
        $obj["avg_r"] = $stats.avg_r
        $obj["r_profit_factor"] = $stats.r_profit_factor
        Format-ObjectForCsv ([pscustomobject]$obj)
    }
    $outRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir $groupSpec.name)
}

Write-Host "Wrote diagnostics to $OutputDir"
