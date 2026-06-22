param(
    [string]$OutputDir = "reports\backtest\runs\20260622_fxbasket_context_trader_2025_diagnostics"
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

function Get-ReportMetric {
    param(
        [string]$Html,
        [string]$Label
    )
    $escaped = [regex]::Escape($Label)
    $pattern = "<td[^>]*>\s*$escaped\s*</td>\s*<td[^>]*><b>(.*?)</b></td>"
    $match = [regex]::Match($Html, $pattern, [Text.RegularExpressions.RegexOptions]::Singleline)
    if ($match.Success) {
        return $match.Groups[1].Value
    }
    return $null
}

function Get-BoldMetricAtLine {
    param(
        [string[]]$Lines,
        [int]$LineNumber
    )
    $line = $Lines[$LineNumber - 1]
    $match = [regex]::Match($line, '<b>(.*?)</b>')
    if ($match.Success) {
        return $match.Groups[1].Value
    }
    return $null
}

function Get-SideStats {
    param([object[]]$Rows)
    $count = @($Rows).Count
    $wins = @($Rows | Where-Object { [double]$_.net_profit -gt 0 }).Count
    $losses = @($Rows | Where-Object { [double]$_.net_profit -lt 0 }).Count
    $grossProfit = ($Rows | ForEach-Object { [double]$_.net_profit } | Where-Object { $_ -gt 0 } | Measure-Object -Sum).Sum
    $grossLoss = ($Rows | ForEach-Object { [double]$_.net_profit } | Where-Object { $_ -lt 0 } | Measure-Object -Sum).Sum
    $netProfit = ($Rows | ForEach-Object { [double]$_.net_profit } | Measure-Object -Sum).Sum
    $sumWinR = ($Rows | ForEach-Object { [double]$_.result_r } | Where-Object { $_ -gt 0 } | Measure-Object -Sum).Sum
    $sumLossR = ($Rows | ForEach-Object { [double]$_.result_r } | Where-Object { $_ -lt 0 } | Measure-Object -Sum).Sum
    $sumR = ($Rows | ForEach-Object { [double]$_.result_r } | Measure-Object -Sum).Sum
    $avgR = if ($count -gt 0) { $sumR / $count } else { 0 }
    $pf = if ($grossLoss -lt 0) { $grossProfit / [math]::Abs($grossLoss) } elseif ($grossProfit -gt 0) { [double]::PositiveInfinity } else { 0 }
    $rpf = if ($sumLossR -lt 0) { $sumWinR / [math]::Abs($sumLossR) } elseif ($sumWinR -gt 0) { [double]::PositiveInfinity } else { 0 }
    [pscustomobject]@{
        trades = $count
        wins = $wins
        losses = $losses
        win_rate = if ($count -gt 0) { $wins / $count } else { 0 }
        net_profit = $netProfit
        gross_profit = $grossProfit
        gross_loss = $grossLoss
        profit_factor_from_trades = $pf
        sum_r = $sumR
        avg_r = $avgR
        r_profit_factor = $rpf
    }
}

function Get-FxBasketSummary {
    param([string]$Path)
    $line = Get-Content $Path | Select-Object -Last 1
    $parts = $line -split ','
    if ($parts.Count -lt 12) {
        throw "Unexpected summary row in $Path"
    }
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

$modes = @(
    @{
        mode = "context_pullback"
        run_dir = "reports\backtest\runs\20260622_fxbasket_context_pullback_2025"
        trades = "fxbasket_context_pullback_trades.csv"
        summary = "fxbasket_context_pullback_summary.csv"
        report = "ExpectedValue_MultiCurrency_FXBasket_ContextTrader_context_pullback_2025_report.html"
    },
    @{
        mode = "volatility_breakout"
        run_dir = "reports\backtest\runs\20260622_fxbasket_volatility_breakout_2025"
        trades = "fxbasket_volatility_breakout_trades.csv"
        summary = "fxbasket_volatility_breakout_summary.csv"
        report = "ExpectedValue_MultiCurrency_FXBasket_ContextTrader_volatility_breakout_2025_report.html"
    },
    @{
        mode = "range_reversion"
        run_dir = "reports\backtest\runs\20260622_fxbasket_range_reversion_2025"
        trades = "fxbasket_range_reversion_trades.csv"
        summary = "fxbasket_range_reversion_summary.csv"
        report = "ExpectedValue_MultiCurrency_FXBasket_ContextTrader_range_reversion_2025_report.html"
    }
)

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$allTrades = New-Object System.Collections.Generic.List[object]
$comparison = New-Object System.Collections.Generic.List[object]

foreach ($mode in $modes) {
    $tradesPath = Join-Path $mode.run_dir $mode.trades
    $summaryPath = Join-Path $mode.run_dir $mode.summary
    $reportPath = Join-Path $mode.run_dir $mode.report
    $rows = @(Import-Csv $tradesPath)
    $summary = Get-FxBasketSummary -Path $summaryPath
    $html = Get-Content $reportPath -Raw
    $reportLines = Get-Content $reportPath
    $tradeStats = Get-SideStats -Rows $rows
    $mt5TotalTrades = Convert-MetricNumber -Value (Get-BoldMetricAtLine -Lines $reportLines -LineNumber 287)
    $mt5NetProfit = Convert-MetricNumber -Value (Get-BoldMetricAtLine -Lines $reportLines -LineNumber 225)
    $mt5GrossProfit = Convert-MetricNumber -Value (Get-BoldMetricAtLine -Lines $reportLines -LineNumber 233)
    $mt5GrossLoss = Convert-MetricNumber -Value (Get-BoldMetricAtLine -Lines $reportLines -LineNumber 241)
    $mt5ProfitFactor = Convert-MetricNumber -Value (Get-BoldMetricAtLine -Lines $reportLines -LineNumber 252)
    $mt5ExpectedPayoff = Convert-MetricNumber -Value (Get-BoldMetricAtLine -Lines $reportLines -LineNumber 254)
    $mt5BalanceMaxDd = Convert-MetricNumber -Value (Get-BoldMetricAtLine -Lines $reportLines -LineNumber 235)
    $mt5EquityMaxDd = Convert-MetricNumber -Value (Get-BoldMetricAtLine -Lines $reportLines -LineNumber 237)
    $mt5RecoveryFactor = Convert-MetricNumber -Value (Get-BoldMetricAtLine -Lines $reportLines -LineNumber 260)

    foreach ($row in $rows) {
        $allTrades.Add([pscustomobject]@{
            mode = $mode.mode
            entry_time = $row.entry_time
            exit_time = $row.exit_time
            symbol = $row.symbol
            direction = $row.direction
            result_r = $row.result_r
            net_profit = $row.net_profit
            volume = $row.volume
            reward_r = $row.reward_r
            holding_bars = $row.holding_bars
            score = $row.score
            exit_reason = $row.exit_reason
        })
    }

    $comparison.Add([pscustomobject]@{
        mode = $mode.mode
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
        passed_trade_count = ([int]$summary.closed_trades -ge 200)
        passed_pf_floor = ($mt5ProfitFactor -ge 1.05)
        promoted_to_long_oos = $false
    })
}

$allTrades | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "trades_all_modes.csv")
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
        result_r = [double]$trade.result_r
        net_profit = [double]$trade.net_profit
    }
}

foreach ($groupSpec in @(
    @{ name = "yearly_breakdown.csv"; keys = @("mode", "year") },
    @{ name = "monthly_breakdown.csv"; keys = @("mode", "month") },
    @{ name = "symbol_breakdown.csv"; keys = @("mode", "symbol") },
    @{ name = "direction_breakdown.csv"; keys = @("mode", "direction") },
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
