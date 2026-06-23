param(
    [string]$OutputDir = "reports\backtest\runs\20260624_fxfractal_dow_elliott_session_diagnostics",
    [string]$CommonFilesDir = "$env:APPDATA\MetaQuotes\Terminal\Common\Files"
)

$ErrorActionPreference = "Stop"
$culture = [Globalization.CultureInfo]::InvariantCulture

$eaName = "ExpectedValue_MultiCurrency_FXFractalDowElliottSessionTrader"
$scenarios = @(
    "baseline_all_sessions",
    "session_volatility_only_filter",
    "london_only_reference",
    "newyork_only_reference",
    "tokyo_only_reference",
    "london_newyork_overlap_reference",
    "symbol_best_session",
    "symbol_best_session_with_dow_alignment",
    "symbol_best_session_with_wave3_confirmed"
)

function Convert-Number {
    param([object]$Value)
    if ($null -eq $Value) { return 0.0 }
    $text = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return 0.0 }
    if ($text -eq "INF") { return [double]::PositiveInfinity }
    return [double]::Parse(($text -replace ",", ""), $culture)
}

function Convert-NullableNumber {
    param([object]$Value)
    if ($null -eq $Value) { return $null }
    $text = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    return [double]::Parse(($text -replace ",", ""), $culture)
}

function Convert-MetricNumber {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $clean = ($Value -replace "<[^>]+>", "" -replace "&nbsp;", " " -replace ",", "" -replace " ", "").Trim()
    $match = [regex]::Match($clean, "[-+]?\d+(?:\.\d+)?")
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
    $match = [regex]::Match($Lines[$LineNumber - 1], "<b>(.*?)</b>")
    if ($match.Success) { return $match.Groups[1].Value }
    return $null
}

function Get-Mt5Metrics {
    param([string]$Path)
    $lines = Get-Content -LiteralPath $Path
    $baseLine = $null
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -like "*<b>100%*") {
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

function Get-SessionSummary {
    param([string]$Path)
    $line = Get-Content -LiteralPath $Path | Select-Object -Last 1
    $parts = $line -split ","
    if ($parts.Count -lt 17) { throw "Unexpected summary row in $Path" }
    $tailStart = $parts.Count - 13
    [pscustomobject]@{
        time = $parts[0]
        strategy = $parts[1]
        scenario_mode = $parts[2]
        symbols = ($parts[3..($tailStart - 1)] -join ",")
        signals = [int]$parts[$tailStart]
        orders_sent = [int]$parts[$tailStart + 1]
        orders_failed = [int]$parts[$tailStart + 2]
        blocked = [int]$parts[$tailStart + 3]
        closed_trades = [int]$parts[$tailStart + 4]
        initial_equity = Convert-Number $parts[$tailStart + 5]
        final_equity = Convert-Number $parts[$tailStart + 6]
        peak_equity = Convert-Number $parts[$tailStart + 7]
        daily_stopped = $parts[$tailStart + 8]
        drawdown_stopped = $parts[$tailStart + 9]
        pivot_future_reference_policy = $parts[$tailStart + 10]
        pivot_confirmation_delay_bars = [int]$parts[$tailStart + 11]
        broker_utc_offset_used = [int]$parts[$tailStart + 12]
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
        wins = $wins
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
        [string]$Scenario,
        [string]$KeyName,
        [string]$KeyValue,
        [object[]]$Rows,
        [hashtable]$Extra = @{}
    )
    $stats = Get-SideStats -Rows $Rows
    $obj = [ordered]@{ scenario_mode = $Scenario }
    foreach ($key in $Extra.Keys) { $obj[$key] = $Extra[$key] }
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

function Add-GroupedStats {
    param(
        [System.Collections.Generic.List[object]]$Target,
        [object[]]$Rows,
        [string]$Scenario,
        [string]$PropertyName,
        [string]$OutputKeyName
    )
    foreach ($group in ($Rows | Group-Object $PropertyName)) {
        $Target.Add((New-GroupStatsObject -Scenario $Scenario -KeyName $OutputKeyName -KeyValue $group.Name -Rows $group.Group))
    }
}

function Add-CompoundGroupedStats {
    param(
        [System.Collections.Generic.List[object]]$Target,
        [object[]]$Rows,
        [string]$Scenario,
        [string]$PrimaryName,
        [string]$PrimaryKey,
        [string]$SecondaryName,
        [string]$SecondaryKey
    )
    foreach ($primary in ($Rows | Group-Object $PrimaryName)) {
        foreach ($secondary in ($primary.Group | Group-Object $SecondaryName)) {
            $Target.Add((New-GroupStatsObject -Scenario $Scenario -KeyName $SecondaryKey -KeyValue $secondary.Name -Rows $secondary.Group -Extra @{ $PrimaryKey = $primary.Name }))
        }
    }
}

function Add-ScriptGroupedStats {
    param(
        [System.Collections.Generic.List[object]]$Target,
        [object[]]$Rows,
        [string]$Scenario,
        [string]$OutputKeyName,
        [scriptblock]$KeyScript
    )
    foreach ($group in ($Rows | Group-Object $KeyScript)) {
        $Target.Add((New-GroupStatsObject -Scenario $Scenario -KeyName $OutputKeyName -KeyValue ([string]$group.Name) -Rows $group.Group))
    }
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

function Test-SymbolConcentration {
    param([object[]]$Rows)
    $stats = Get-SideStats -Rows $Rows
    if ($stats.net_profit -le 0) { return $false }
    $symbolStats = foreach ($group in ($Rows | Group-Object symbol)) {
        $s = Get-SideStats -Rows $group.Group
        [pscustomobject]@{ symbol = $group.Name; net_profit = $s.net_profit }
    }
    $positive = @($symbolStats | Where-Object { $_.net_profit -gt 0 })
    if ($positive.Count -lt 2) { return $false }
    $maxProfit = ($positive | Measure-Object -Property net_profit -Maximum).Maximum
    return ($maxProfit / $stats.net_profit) -lt 0.75
}

function Test-SessionConcentration {
    param([object[]]$Rows)
    if ($Rows.Count -eq 0) { return $false }
    $groups = @($Rows | Group-Object session_label)
    if ($groups.Count -lt 2) { return $false }
    $maxCount = ($groups | ForEach-Object { $_.Count } | Measure-Object -Maximum).Maximum
    return ($maxCount / $Rows.Count) -lt 0.75
}

function Get-PrimaryGateScope {
    param([string]$Scenario)
    return $Scenario -in @(
        "baseline_all_sessions",
        "session_volatility_only_filter",
        "symbol_best_session",
        "symbol_best_session_with_dow_alignment",
        "symbol_best_session_with_wave3_confirmed"
    )
}

function Get-RunDirForScenario {
    param([string]$Scenario)
    return Join-Path "reports\backtest\runs" ("20260624_fxfractal_{0}_2025" -f $Scenario)
}

function Copy-ScenarioArtifacts {
    param([string]$Scenario)
    $runDir = Get-RunDirForScenario -Scenario $Scenario
    New-Item -ItemType Directory -Force -Path $runDir | Out-Null

    $commonDir = Join-Path $CommonFilesDir ("fxfractal_{0}_2025" -f $Scenario)
    if (-not (Test-Path -LiteralPath $commonDir)) { throw "Missing Common Files output: $commonDir" }

    $map = @{
        ("fxfractal_{0}_trades.csv" -f $Scenario) = "trades.csv"
        ("fxfractal_{0}_signals.csv" -f $Scenario) = "signals.csv"
        ("fxfractal_{0}_summary.csv" -f $Scenario) = "summary.csv"
        ("fxfractal_{0}_session_audit.csv" -f $Scenario) = "session_audit.csv"
    }
    foreach ($sourceName in $map.Keys) {
        $source = Join-Path $commonDir $sourceName
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $runDir $map[$sourceName]) -Force
        }
    }

    Copy-Item -LiteralPath (Join-Path "reports\presets" ("{0}_{1}_2025.set" -f $eaName, $Scenario)) -Destination (Join-Path $runDir "preset.set") -Force
    Copy-Item -LiteralPath (Join-Path "reports\backtest" ("{0}_{1}_2025.ini" -f $eaName, $Scenario)) -Destination (Join-Path $runDir "tester.ini") -Force
    foreach ($reportFile in Get-ChildItem -LiteralPath "reports\backtest" -Filter ("{0}_{1}_2025_report*" -f $eaName, $Scenario)) {
        Copy-Item -LiteralPath $reportFile.FullName -Destination (Join-Path $runDir $reportFile.Name.Replace(("{0}_{1}_2025_" -f $eaName, $Scenario), "")) -Force
    }
    return $runDir
}

function Get-AuditAverage {
    param([object[]]$Rows, [string]$PropertyName)
    $values = @($Rows | ForEach-Object { Convert-NullableNumber $_.$PropertyName } | Where-Object { $null -ne $_ })
    if ($values.Count -eq 0) { return 0.0 }
    return ($values | Measure-Object -Average).Average
}

function Get-CsvHeaderMap {
    param([string]$Path)
    $header = Get-Content -LiteralPath $Path -TotalCount 1
    $columns = $header.Split([char]",")
    $map = @{}
    for ($i = 0; $i -lt $columns.Count; $i++) {
        $map[$columns[$i]] = $i
    }
    return $map
}

function Get-CsvField {
    param(
        [string[]]$Fields,
        [hashtable]$Map,
        [string]$Name
    )
    if (-not $Map.ContainsKey($Name)) { return "" }
    $idx = $Map[$Name]
    if ($idx -ge $Fields.Count) { return "" }
    return $Fields[$idx]
}

function Get-SignalEventRows {
    param(
        [string]$Path,
        [string]$Scenario
    )
    $map = Get-CsvHeaderMap -Path $Path
    $eventIndex = $map["event"]
    $counts = @{}
    $reader = [System.IO.StreamReader]::new($Path)
    try {
        $null = $reader.ReadLine()
        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $parts = $line.Split([char]",")
            if ($eventIndex -ge $parts.Count) { continue }
            $event = $parts[$eventIndex]
            if (-not $counts.ContainsKey($event)) { $counts[$event] = 0 }
            $counts[$event]++
        }
    } finally {
        $reader.Close()
    }
    foreach ($key in ($counts.Keys | Sort-Object)) {
        [pscustomobject]@{
            scenario_mode = $Scenario
            event = $key
            count = $counts[$key]
        }
    }
}

function Get-SessionAuditSummaryRows {
    param(
        [string]$Path,
        [string]$Scenario
    )
    $map = Get-CsvHeaderMap -Path $Path
    $groups = @{}
    $reader = [System.IO.StreamReader]::new($Path)
    try {
        $null = $reader.ReadLine()
        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $parts = $line.Split([char]",")
            $symbol = Get-CsvField -Fields $parts -Map $map -Name "symbol"
            $sessionLabel = Get-CsvField -Fields $parts -Map $map -Name "session_label"
            $key = "$symbol|$sessionLabel"
            if (-not $groups.ContainsKey($key)) {
                $groups[$key] = [ordered]@{
                    scenario_mode = $Scenario
                    symbol = $symbol
                    session_label = $sessionLabel
                    session_window_name = Get-CsvField -Fields $parts -Map $map -Name "session_window_name"
                    rows = 0
                    average_m15_range_atr_sum = 0.0
                    average_h1_range_atr_sum = 0.0
                    average_true_range_sum = 0.0
                    realized_volatility_sum = 0.0
                    breakout_followthrough_rate_sum = 0.0
                    average_spread_atr_sum = 0.0
                    atr_session_percentile_sum = 0.0
                    avg_R_if_traded_sum = 0.0
                    PF_if_traded_sum = 0.0
                    trade_count_candidate = 0.0
                    net_if_traded = 0.0
                }
            }
            $group = $groups[$key]
            $group.rows++
            $group.average_m15_range_atr_sum += Convert-Number (Get-CsvField -Fields $parts -Map $map -Name "average_m15_range_atr")
            $group.average_h1_range_atr_sum += Convert-Number (Get-CsvField -Fields $parts -Map $map -Name "average_h1_range_atr")
            $group.average_true_range_sum += Convert-Number (Get-CsvField -Fields $parts -Map $map -Name "average_true_range")
            $group.realized_volatility_sum += Convert-Number (Get-CsvField -Fields $parts -Map $map -Name "realized_volatility")
            $group.breakout_followthrough_rate_sum += Convert-Number (Get-CsvField -Fields $parts -Map $map -Name "breakout_followthrough_rate")
            $group.average_spread_atr_sum += Convert-Number (Get-CsvField -Fields $parts -Map $map -Name "average_spread_atr")
            $group.atr_session_percentile_sum += Convert-Number (Get-CsvField -Fields $parts -Map $map -Name "atr_session_percentile")
            $group.avg_R_if_traded_sum += Convert-Number (Get-CsvField -Fields $parts -Map $map -Name "avg_R_if_traded")
            $group.PF_if_traded_sum += Convert-Number (Get-CsvField -Fields $parts -Map $map -Name "PF_if_traded")
            $group.trade_count_candidate += Convert-Number (Get-CsvField -Fields $parts -Map $map -Name "trade_count_candidate")
            $group.net_if_traded += Convert-Number (Get-CsvField -Fields $parts -Map $map -Name "net_if_traded")
        }
    } finally {
        $reader.Close()
    }

    foreach ($key in ($groups.Keys | Sort-Object)) {
        $group = $groups[$key]
        $rows = [double]$group.rows
        [pscustomobject]@{
            scenario_mode = $group.scenario_mode
            symbol = $group.symbol
            session_label = $group.session_label
            session_window_name = $group.session_window_name
            rows = $group.rows
            average_m15_range_atr = if ($rows -gt 0) { $group.average_m15_range_atr_sum / $rows } else { 0.0 }
            average_h1_range_atr = if ($rows -gt 0) { $group.average_h1_range_atr_sum / $rows } else { 0.0 }
            average_true_range = if ($rows -gt 0) { $group.average_true_range_sum / $rows } else { 0.0 }
            realized_volatility = if ($rows -gt 0) { $group.realized_volatility_sum / $rows } else { 0.0 }
            breakout_followthrough_rate = if ($rows -gt 0) { $group.breakout_followthrough_rate_sum / $rows } else { 0.0 }
            average_spread_atr = if ($rows -gt 0) { $group.average_spread_atr_sum / $rows } else { 0.0 }
            atr_session_percentile = if ($rows -gt 0) { $group.atr_session_percentile_sum / $rows } else { 0.0 }
            trade_count_candidate = $group.trade_count_candidate
            avg_R_if_traded = if ($rows -gt 0) { $group.avg_R_if_traded_sum / $rows } else { 0.0 }
            PF_if_traded = if ($rows -gt 0) { $group.PF_if_traded_sum / $rows } else { 0.0 }
            net_if_traded = $group.net_if_traded
        }
    }
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$comparison = New-Object System.Collections.Generic.List[object]
$allTrades = New-Object System.Collections.Generic.List[object]
$yearly = New-Object System.Collections.Generic.List[object]
$monthly = New-Object System.Collections.Generic.List[object]
$sessionBreakdown = New-Object System.Collections.Generic.List[object]
$hourBreakdown = New-Object System.Collections.Generic.List[object]
$symbolSessionBreakdown = New-Object System.Collections.Generic.List[object]
$setupSessionBreakdown = New-Object System.Collections.Generic.List[object]
$directionSessionBreakdown = New-Object System.Collections.Generic.List[object]
$dowRegimeBreakdown = New-Object System.Collections.Generic.List[object]
$waveStageBreakdown = New-Object System.Collections.Generic.List[object]
$setupTypeBreakdown = New-Object System.Collections.Generic.List[object]
$failureBreakdown = New-Object System.Collections.Generic.List[object]
$symbolBreakdown = New-Object System.Collections.Generic.List[object]
$directionBreakdown = New-Object System.Collections.Generic.List[object]
$m15Breakdown = New-Object System.Collections.Generic.List[object]
$fibZoneBreakdown = New-Object System.Collections.Generic.List[object]
$divergenceBreakdown = New-Object System.Collections.Generic.List[object]
$wave3Breakdown = New-Object System.Collections.Generic.List[object]
$rMetrics = New-Object System.Collections.Generic.List[object]
$auditSummary = New-Object System.Collections.Generic.List[object]
$signalEventBreakdown = New-Object System.Collections.Generic.List[object]

foreach ($scenario in $scenarios) {
    Write-Host "Analyzing $scenario"
    $runDir = Copy-ScenarioArtifacts -Scenario $scenario
    $trades = @(Import-Csv (Join-Path $runDir "trades.csv"))
    $summary = Get-SessionSummary -Path (Join-Path $runDir "summary.csv")
    $metrics = Get-Mt5Metrics -Path (Join-Path $runDir "report.html")
    $tradeStats = Get-SideStats -Rows $trades
    $rStats = Get-RMetricStats -Rows $trades

    foreach ($row in $trades) {
        $obj = [ordered]@{ scenario_mode = $scenario }
        foreach ($prop in $row.PSObject.Properties) { $obj[$prop.Name] = $prop.Value }
        $allTrades.Add([pscustomobject]$obj)
    }

    foreach ($group in ($trades | Group-Object { (Convert-TradeDate $_.entry_time).ToString("yyyy", $culture) })) {
        $yearly.Add((New-GroupStatsObject -Scenario $scenario -KeyName "year" -KeyValue $group.Name -Rows $group.Group))
    }
    foreach ($group in ($trades | Group-Object { (Convert-TradeDate $_.entry_time).ToString("yyyy-MM", $culture) })) {
        $monthly.Add((New-GroupStatsObject -Scenario $scenario -KeyName "month" -KeyValue $group.Name -Rows $group.Group))
    }

    Add-GroupedStats -Target $sessionBreakdown -Rows $trades -Scenario $scenario -PropertyName "session_label" -OutputKeyName "session_label"
    Add-ScriptGroupedStats -Target $hourBreakdown -Rows $trades -Scenario $scenario -OutputKeyName "server_hour" -KeyScript { $_.server_hour }
    Add-GroupedStats -Target $symbolBreakdown -Rows $trades -Scenario $scenario -PropertyName "symbol" -OutputKeyName "symbol"
    Add-GroupedStats -Target $directionBreakdown -Rows $trades -Scenario $scenario -PropertyName "direction" -OutputKeyName "direction"
    Add-GroupedStats -Target $waveStageBreakdown -Rows $trades -Scenario $scenario -PropertyName "wave_stage" -OutputKeyName "wave_stage"
    Add-GroupedStats -Target $setupTypeBreakdown -Rows $trades -Scenario $scenario -PropertyName "setup_type" -OutputKeyName "setup_type"
    Add-GroupedStats -Target $fibZoneBreakdown -Rows $trades -Scenario $scenario -PropertyName "fib_zone" -OutputKeyName "fib_zone"
    Add-GroupedStats -Target $divergenceBreakdown -Rows $trades -Scenario $scenario -PropertyName "divergence_type" -OutputKeyName "divergence_type"
    Add-GroupedStats -Target $failureBreakdown -Rows $trades -Scenario $scenario -PropertyName "failure_type" -OutputKeyName "failure_type"
    Add-GroupedStats -Target $m15Breakdown -Rows $trades -Scenario $scenario -PropertyName "m15_confirmation_type" -OutputKeyName "m15_confirmation_type"
    Add-CompoundGroupedStats -Target $symbolSessionBreakdown -Rows $trades -Scenario $scenario -PrimaryName "symbol" -PrimaryKey "symbol" -SecondaryName "session_label" -SecondaryKey "session_label"
    Add-CompoundGroupedStats -Target $setupSessionBreakdown -Rows $trades -Scenario $scenario -PrimaryName "setup_type" -PrimaryKey "setup_type" -SecondaryName "session_label" -SecondaryKey "session_label"
    Add-CompoundGroupedStats -Target $directionSessionBreakdown -Rows $trades -Scenario $scenario -PrimaryName "direction" -PrimaryKey "direction" -SecondaryName "session_label" -SecondaryKey "session_label"
    Add-CompoundGroupedStats -Target $dowRegimeBreakdown -Rows $trades -Scenario $scenario -PrimaryName "dow_regime_h4" -PrimaryKey "dow_regime_h4" -SecondaryName "dow_regime_h1" -SecondaryKey "dow_regime_h1"
    Add-ScriptGroupedStats -Target $wave3Breakdown -Rows $trades -Scenario $scenario -OutputKeyName "wave3_break_confirmed" -KeyScript { $_.wave3_break_confirmed }

    foreach ($row in (Get-SignalEventRows -Path (Join-Path $runDir "signals.csv") -Scenario $scenario)) {
        $signalEventBreakdown.Add($row)
    }

    foreach ($row in (Get-SessionAuditSummaryRows -Path (Join-Path $runDir "session_audit.csv") -Scenario $scenario)) {
        $auditSummary.Add($row)
    }

    $passedTradeCount = $summary.closed_trades -ge 200
    $passedPf = $metrics.profit_factor -ge 1.05
    $passedAvgR = $tradeStats.avg_r -gt 0
    $passedNet = $metrics.net_profit -gt 0
    $passedDdStop = $summary.drawdown_stopped -ne "true"
    $passedDirection = Test-DirectionBalance -Rows $trades
    $passedSymbol = Test-SymbolConcentration -Rows $trades
    $passedSession = Test-SessionConcentration -Rows $trades
    $primaryGateScope = Get-PrimaryGateScope -Scenario $scenario
    $passedShallow = $primaryGateScope -and $passedTradeCount -and $passedPf -and $passedAvgR -and $passedNet -and $passedDdStop -and $passedDirection -and $passedSymbol -and $passedSession

    $failed = New-Object System.Collections.Generic.List[string]
    if (-not $primaryGateScope) { $failed.Add("reference_only_not_primary_gate") }
    if (-not $passedTradeCount) { $failed.Add("trades_lt_200") }
    if (-not $passedPf) { $failed.Add("pf_lt_1.05") }
    if (-not $passedAvgR) { $failed.Add("avg_r_le_0") }
    if (-not $passedNet) { $failed.Add("net_le_0") }
    if (-not $passedDdStop) { $failed.Add("dd_stopped") }
    if (-not $passedDirection) { $failed.Add("direction_balance_failed") }
    if (-not $passedSymbol) { $failed.Add("symbol_concentration_or_negative_net") }
    if (-not $passedSession) { $failed.Add("session_concentration") }

    $rMetrics.Add([pscustomobject]@{
        scenario_mode = $scenario
        trades = $rStats.trades
        sum_r = $rStats.sum_r
        avg_r = $rStats.avg_r
        median_r = $rStats.median_r
        min_r = $rStats.min_r
        max_r = $rStats.max_r
        stdev_r = $rStats.stdev_r
        p25_r = $rStats.p25_r
        p75_r = $rStats.p75_r
        avg_win_r = $rStats.avg_win_r
        avg_loss_r = $rStats.avg_loss_r
        payoff_r = $rStats.payoff_r
    })

    $comparison.Add([pscustomobject]@{
        scenario_mode = $scenario
        primary_gate_scope = $primaryGateScope
        signals = $summary.signals
        orders_sent = $summary.orders_sent
        orders_failed = $summary.orders_failed
        blocked = $summary.blocked
        closed_trades = $summary.closed_trades
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
        daily_stopped = $summary.daily_stopped
        drawdown_stopped = $summary.drawdown_stopped
        pivot_future_reference_policy = $summary.pivot_future_reference_policy
        pivot_confirmation_delay_bars = $summary.pivot_confirmation_delay_bars
        broker_utc_offset_used = $summary.broker_utc_offset_used
        passed_trade_count = $passedTradeCount
        passed_pf_floor = $passedPf
        passed_avg_r = $passedAvgR
        passed_net = $passedNet
        passed_dd_stop = $passedDdStop
        passed_direction_balance = $passedDirection
        passed_symbol_concentration = $passedSymbol
        passed_session_concentration = $passedSession
        passed_2025_shallow_gate = $passedShallow
        promoted_to_3y_oos = $false
        failed_conditions = ($failed -join ";")
    })
    Write-Host "Finished $scenario"
}

$comparisonRows = @($comparison.ToArray())
$allTradesRows = @($allTrades.ToArray())

$comparisonRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "comparison.csv")
$allTradesRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "trades_all_scenarios.csv")
$yearly | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "yearly_breakdown.csv")
$monthly | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "monthly_breakdown.csv")
$sessionBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "session_breakdown.csv")
$hourBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "hour_breakdown.csv")
$symbolSessionBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "symbol_session_breakdown.csv")
$setupSessionBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "setup_session_breakdown.csv")
$directionSessionBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "direction_session_breakdown.csv")
$dowRegimeBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "dow_regime_breakdown.csv")
$waveStageBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "wave_stage_breakdown.csv")
$setupTypeBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "setup_type_breakdown.csv")
$failureBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "failure_type_breakdown.csv")
$symbolBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "symbol_breakdown.csv")
$directionBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "direction_breakdown.csv")
$m15Breakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "m15_confirmation_breakdown.csv")
$fibZoneBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "fib_zone_breakdown.csv")
$divergenceBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "divergence_breakdown.csv")
$wave3Breakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "wave3_break_confirmed_breakdown.csv")
$rMetrics | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "r_metrics.csv")
$auditSummary | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "session_volatility_audit.csv")
$signalEventBreakdown | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutputDir "signal_event_breakdown.csv")

Copy-Item -LiteralPath "reports\compile\ExpectedValue_MultiCurrency_FXFractalDowElliottSessionTrader_compile.txt" -Destination (Join-Path $OutputDir "compile.txt") -Force

$primaryRows = @($comparisonRows | Where-Object { $_.primary_gate_scope -eq $true })
$passedRows = @($comparisonRows | Where-Object { $_.passed_2025_shallow_gate -eq $true })
$bestNet = @($comparisonRows | Sort-Object net_profit -Descending | Select-Object -First 1)[0]
$bestAvgR = @($comparisonRows | Sort-Object avg_r -Descending | Select-Object -First 1)[0]
$bestPrimary = @($primaryRows | Sort-Object avg_r -Descending | Select-Object -First 1)[0]
$bestSessionAudit = @($auditSummary | Sort-Object avg_R_if_traded -Descending | Select-Object -First 10)
$wave3ConfirmStats = @($wave3Breakdown | Sort-Object scenario_mode,wave3_break_confirmed)
$largestFailure = @($failureBreakdown | Sort-Object net_profit | Select-Object -First 1)[0]
$bestSetupSession = @($setupSessionBreakdown | Sort-Object avg_r -Descending | Select-Object -First 1)[0]
$bestDow = @($dowRegimeBreakdown | Sort-Object avg_r -Descending | Select-Object -First 1)[0]

$summaryLines = New-Object System.Collections.Generic.List[string]
$summaryLines.Add("# FX Fractal Dow Elliott Session Diagnostics")
$summaryLines.Add("")
$summaryLines.Add("## Implementation Notes")
$summaryLines.Add("- This EA is `ExpectedValue_MultiCurrency_FXFractalDowElliottSessionTrader` with strategy tag `RESEARCH_STRATEGY_FX_FRACTAL_DOW_ELLIOTT_SESSION`.")
$summaryLines.Add("- Elliott Wave is implemented as a roadmap label, not strict wave counting. The EA records wave_stage, setup_type, fib_zone, divergence_type, wave3_break_confirmed, pivot timing, Dow regimes, session labels, and volatility ranks.")
$summaryLines.Add("- H1/H4 pivots use confirmed closed bars only. With InpSwingDepth=3, pivots are usable only after the right-side 3 closed bars. ZigZag repaint buffers are not used. Summary policy: confirmed_pivots_only_no_repaint_zigzag.")
$summaryLines.Add("- Symbols tested: USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD. No XAUUSD, symbol exclusion, direction-only gate, Friday stop, or narrow threshold repair was used.")
$summaryLines.Add("- Session labels are derived from server time using broker_utc_offset_used=2. Overlap is labeled before London/New York for UTC 13-16.")
$summaryLines.Add("")
$summaryLines.Add("## 2025 Shallow BT Comparison")
foreach ($row in $comparisonRows) {
    $summaryLines.Add(("- {0}: trades={1}, PF={2:n2}, avg_R={3:n4}, net={4:n2}, DD_stop={5}, primary_gate={6}, passed={7}, failed={8}" -f $row.scenario_mode, $row.closed_trades, $row.profit_factor, $row.avg_r, $row.net_profit, $row.drawdown_stopped, $row.primary_gate_scope, $row.passed_2025_shallow_gate, $row.failed_conditions))
}
$summaryLines.Add("")
$summaryLines.Add("## Session Findings")
$summaryLines.Add(("- Best scenario by net: {0}, net={1:n2}, PF={2:n2}, avg_R={3:n4}, DD_stop={4}." -f $bestNet.scenario_mode, $bestNet.net_profit, $bestNet.profit_factor, $bestNet.avg_r, $bestNet.drawdown_stopped))
$summaryLines.Add(("- Best scenario by avg_R: {0}, trades={1}, avg_R={2:n4}, PF={3:n2}." -f $bestAvgR.scenario_mode, $bestAvgR.closed_trades, $bestAvgR.avg_r, $bestAvgR.profit_factor))
$summaryLines.Add(("- Best primary-gate scenario by avg_R: {0}, trades={1}, avg_R={2:n4}, PF={3:n2}, failed={4}." -f $bestPrimary.scenario_mode, $bestPrimary.closed_trades, $bestPrimary.avg_r, $bestPrimary.profit_factor, $bestPrimary.failed_conditions))
$summaryLines.Add("- Top symbol/session audit buckets by avg_R_if_traded:")
foreach ($row in $bestSessionAudit) {
    $summaryLines.Add(("  - {0}/{1}/{2}: avg_R_if_traded={3:n4}, PF_if_traded={4:n2}, net_if_traded={5:n2}, avg_m15_range_atr={6:n3}, followthrough={7:n3}" -f $row.scenario_mode, $row.symbol, $row.session_label, $row.avg_R_if_traded, $row.PF_if_traded, $row.net_if_traded, $row.average_m15_range_atr, $row.breakout_followthrough_rate))
}
$summaryLines.Add("")
$summaryLines.Add("## Diagnostic Findings")
$summaryLines.Add(("- Best setup/session bucket: {0}/{1}/{2}, trades={3}, avg_R={4:n4}, PF_from_trades={5:n2}." -f $bestSetupSession.scenario_mode, $bestSetupSession.setup_type, $bestSetupSession.session_label, $bestSetupSession.trades, $bestSetupSession.avg_r, $bestSetupSession.profit_factor_from_trades))
$summaryLines.Add(("- Best Dow regime bucket: {0}, H4={1}, H1={2}, trades={3}, avg_R={4:n4}." -f $bestDow.scenario_mode, $bestDow.dow_regime_h4, $bestDow.dow_regime_h1, $bestDow.trades, $bestDow.avg_r))
$summaryLines.Add(("- Largest losing failure bucket: {0}/{1}, trades={2}, net={3:n2}, avg_R={4:n4}." -f $largestFailure.scenario_mode, $largestFailure.failure_type, $largestFailure.trades, $largestFailure.net_profit, $largestFailure.avg_r))
$summaryLines.Add("- wave3_break_confirmed comparison:")
foreach ($row in $wave3ConfirmStats) {
    $summaryLines.Add(("  - {0}, wave3_break_confirmed={1}: trades={2}, avg_R={3:n4}, PF_from_trades={4:n2}" -f $row.scenario_mode, $row.wave3_break_confirmed, $row.trades, $row.avg_r, $row.profit_factor_from_trades))
}
$summaryLines.Add("- M15 confirmation, wave_stage, setup_type, fib_zone, divergence_type, failure_type, Dow regime, session, symbol-session, setup-session, and direction-session details are in the generated CSVs.")
$summaryLines.Add("")
$summaryLines.Add("## Promotion Decision")
if ($passedRows.Count -gt 0) {
    $summaryLines.Add("- One or more primary scenarios passed the 2025 shallow gate and should be promoted manually to 3-year fixed BT and latest 12-month OOS.")
    foreach ($row in $passedRows) {
        $summaryLines.Add(("- Promote candidate: {0}" -f $row.scenario_mode))
    }
} else {
    $summaryLines.Add("- No primary scenario passed the 2025 shallow gate, so no 3-year fixed BT or latest 12-month OOS was run.")
}
$summaryLines.Add("- Deployable candidate from this cycle: none unless a later manual review overrides the no-promotion rule, which is not recommended from this dataset.")
$summaryLines | Set-Content -Path (Join-Path $OutputDir "summary.md") -Encoding UTF8

Write-Host "Wrote diagnostics to $OutputDir"
