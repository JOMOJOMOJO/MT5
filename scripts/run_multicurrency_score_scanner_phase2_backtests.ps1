param(
    [string]$TerminalPath = "C:\Users\windows\AppData\Local\CodexMT5BucketLab\terminal64.exe",
    [int]$TimeoutSeconds = 14400,
    [string[]]$RunIds = @("A", "B", "C", "D", "E", "F")
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$backtestDir = Join-Path $repoRoot "reports\backtest"
$presetDir = Join-Path $repoRoot "reports\presets"
$portableRoot = Split-Path -Parent (Resolve-Path $TerminalPath).Path
$resolvedTerminalPath = (Resolve-Path $TerminalPath).Path
$commonFilesRoot = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$resolvedCommonFilesRoot = (Resolve-Path $commonFilesRoot).Path
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
        [string]$Name
    )

    $prefix = "ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_$Name"
    [pscustomobject]@{
        Id = $Id
        Prefix = $prefix
        IniPath = Join-Path $backtestDir "$prefix.ini"
        PresetPath = Join-Path $presetDir "$prefix.set"
        PresetName = "$prefix.set"
        ReportStem = "${prefix}_report"
        LogFolder = "multicurrency_score_scanner_2025_phase2_$Name"
    }
}

$runs = @(
    New-Run -Id "A" -Name "A_both_5m"
    New-Run -Id "B" -Name "B_long_only_5m"
    New-Run -Id "C" -Name "C_short_only_5m"
    New-Run -Id "D" -Name "D_long_structure_5m"
    New-Run -Id "E" -Name "E_xau_long_structure_5m"
    New-Run -Id "F" -Name "F_disable_usdjpy_short_5m"
)

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

    $scoreFiles = @(Get-ChildItem -Path $logDir -File -Filter "multicurrency_score_*.csv" |
        Where-Object { $_.Name -notlike "multicurrency_score_scan_*" -and $_.Name -notlike "multicurrency_score_structure_*" })
    $scanFiles = @(Get-ChildItem -Path $logDir -File -Filter "multicurrency_score_scan_*.csv")
    $structureFiles = @(Get-ChildItem -Path $logDir -File -Filter "multicurrency_score_structure_*.csv" |
        Where-Object { $_.Name -notlike "multicurrency_score_structure_summary_*" })
    $structureSummaryFiles = @(Get-ChildItem -Path $logDir -File -Filter "multicurrency_score_structure_summary_*.csv")

    Join-CsvFiles -Files $scoreFiles -OutputPath (Join-Path $backtestDir "$($Run.Prefix)_scores.csv") -EmptyHeader @("time", "symbol", "direction", "totalScore", "trendScore", "setupScore", "volatilityScore", "costPenalty", "riskPenalty", "reason")
    Join-CsvFiles -Files $scanFiles -OutputPath (Join-Path $backtestDir "$($Run.Prefix)_scan_diagnostics.csv") -EmptyHeader @("time", "event", "last_scan_bar_time", "scan_elapsed_ms", "reason")
    Join-CsvFiles -Files $structureFiles -OutputPath (Join-Path $backtestDir "$($Run.Prefix)_structure_diagnostics.csv") -EmptyHeader @("time", "symbol", "direction", "trend_up", "trend_down", "higher_high", "higher_low", "lower_high", "lower_low", "pullback_valid", "pullback_too_deep", "fractal_confirmed", "reclaim_confirmed", "structure_filter_pass", "structure_filter_fail_reason", "structure_stop_reference")
    Join-CsvFiles -Files $structureSummaryFiles -OutputPath (Join-Path $backtestDir "$($Run.Prefix)_structure_summary.csv") -EmptyHeader @("time", "structure_evaluations", "structure_detail_rows", "structure_pass", "structure_fail", "structure_pass_rate", "no_context_swings", "no_trend_up", "no_trend_down", "pullback_too_deep", "pullback_not_valid", "no_fractal_low", "no_fractal_high", "not_enough_fractals", "no_reclaim", "unknown", "structure_top_fail_reason", "structure_top_fail_reason_rows")
}

function Run-Backtest {
    param([object]$Run)

    if (-not (Test-Path $Run.IniPath)) {
        throw "Missing ini: $($Run.IniPath)"
    }
    if (-not (Test-Path $Run.PresetPath)) {
        throw "Missing preset: $($Run.PresetPath)"
    }

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
    Write-Host "[$($Run.Id)] completed in $([math]::Round($elapsed.TotalSeconds, 1)) seconds"
}

Sync-EaToPortable

foreach ($run in $runs) {
    if ($requestedRunIds -notcontains $run.Id) {
        continue
    }
    Run-Backtest -Run $run
}
