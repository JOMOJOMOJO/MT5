param(
    [string]$TerminalPath = "C:\Program Files\XMTrading MT5 - 2\terminal64.exe",
    [string]$MatrixPath = "reports\backtest\runs\20260710_session_reversal_m15_anchor_first_break_pullback\run_matrix.csv",
    [string]$RunRootPath = "reports\backtest\runs\20260710_session_reversal_m15_anchor_first_break_pullback",
    [string]$AnalysisScript = "scripts\analyze-session-reversal-m15-anchor-first-break-cycles.py",
    [int]$TimeoutSecondsPerRun = 2700,
    [int]$StartAt = 1,
    [int]$Limit = 0,
    [switch]$Force,
    [switch]$AnalyzeWhenDone
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$terminalDataRoot = (Resolve-Path (Join-Path $repoRoot "..\..\..")).Path
$commonFiles = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$runRoot = if ([System.IO.Path]::IsPathRooted($RunRootPath)) { $RunRootPath } else { Join-Path $repoRoot $RunRootPath }
$statusPath = Join-Path $runRoot "batch_status.csv"
$batchLogPath = Join-Path $runRoot ("batch_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

New-Item -ItemType Directory -Path $runRoot -Force | Out-Null

function Write-BatchLog {
    param([string]$Message)
    $line = ("{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message)
    Write-Host $line
    Add-Content -LiteralPath $batchLogPath -Value $line -Encoding UTF8
}

function Resolve-RepoPath {
    param([string]$PathValue)
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return $PathValue
    }
    return (Join-Path $repoRoot $PathValue)
}

function Get-KeyValue {
    param([string[]]$Lines, [string]$Key)
    $line = $Lines | Where-Object { $_ -match "^\s*$([regex]::Escape($Key))=" } | Select-Object -First 1
    if (-not $line) {
        return $null
    }
    return ($line -replace "^\s*$([regex]::Escape($Key))=", "").Trim()
}

function Get-ReportPathFromIni {
    param([string]$IniPath)
    $lines = Get-Content -LiteralPath $IniPath
    $reportValue = Get-KeyValue -Lines $lines -Key "Report"
    if (-not $reportValue) {
        return $null
    }
    if (-not [System.IO.Path]::GetExtension($reportValue)) {
        $reportValue = "$reportValue.htm"
    }
    if ([System.IO.Path]::IsPathRooted($reportValue)) {
        return $reportValue
    }
    return (Join-Path $terminalDataRoot $reportValue)
}

function Get-LogFolderFromPreset {
    param([string]$PresetPath)
    if (-not (Test-Path -LiteralPath $PresetPath)) {
        return $null
    }
    $lines = Get-Content -LiteralPath $PresetPath
    return Get-KeyValue -Lines $lines -Key "InpLogFolder"
}

function Resolve-EaCsvPath {
    param([string]$Folder, [string]$ScenarioName, [string]$Suffix)
    if (-not $Folder) {
        return $null
    }
    $names = @(
        ("fxsessionrev_{0}_{1}.csv" -f $ScenarioName, $Suffix),
        ("fxsessionrev_session_reversal_pullback_{0}_{1}.csv" -f $ScenarioName, $Suffix)
    )
    foreach ($name in $names) {
        $candidate = Join-Path $Folder $name
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }
    if (Test-Path -LiteralPath $Folder) {
        $match = Get-ChildItem -LiteralPath $Folder -Filter ("fxsessionrev_*_{0}.csv" -f $Suffix) -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($match) {
            return $match.FullName
        }
    }
    return (Join-Path $Folder $names[0])
}

function Test-RunComplete {
    param([string]$ReportPath, [string]$SummaryPath)
    return ($ReportPath -and (Test-Path -LiteralPath $ReportPath) -and
        (Test-Path -LiteralPath "$ReportPath.meta.json") -and
        $SummaryPath -and (Test-Path -LiteralPath $SummaryPath))
}

function Append-Status {
    param([object]$Row)
    $exists = Test-Path -LiteralPath $statusPath
    $Row | Export-Csv -LiteralPath $statusPath -NoTypeInformation -Append:$exists -Encoding UTF8
}

$resolvedMatrixPath = Resolve-RepoPath $MatrixPath
if (-not (Test-Path -LiteralPath $resolvedMatrixPath)) {
    throw "Matrix file was not found: $resolvedMatrixPath"
}
if (-not (Test-Path -LiteralPath $TerminalPath)) {
    throw "MT5 terminal was not found: $TerminalPath"
}

$runs = @(Import-Csv -LiteralPath $resolvedMatrixPath)
if ($StartAt -lt 1) {
    $StartAt = 1
}
$selected = @($runs | Select-Object -Skip ($StartAt - 1))
if ($Limit -gt 0) {
    $selected = @($selected | Select-Object -First $Limit)
}

Write-BatchLog "Starting M15 anchor first-break batch. terminal=$TerminalPath matrix=$resolvedMatrixPath selected=$($selected.Count) timeout_per_run=$TimeoutSecondsPerRun force=$Force"

$index = $StartAt - 1
foreach ($run in $selected) {
    $index += 1
    $runId = $run.run_id
    $scenarioName = $run.scenario_name
    $iniPath = Resolve-RepoPath $run.tester_ini
    $presetPath = Resolve-RepoPath $run.preset
    $reportPath = Get-ReportPathFromIni -IniPath $iniPath
    $logFolder = Get-LogFolderFromPreset -PresetPath $presetPath
    $commonRunFolder = if ($logFolder) { Join-Path $commonFiles $logFolder } else { $null }
    $summaryPath = Resolve-EaCsvPath -Folder $commonRunFolder -ScenarioName $scenarioName -Suffix "summary"

    if (-not $Force -and (Test-RunComplete -ReportPath $reportPath -SummaryPath $summaryPath)) {
        Write-BatchLog "[$index/$($runs.Count)] SKIP completed run_id=$runId"
        Append-Status ([pscustomobject]@{
            timestamp = (Get-Date).ToString("o")
            run_index = $index
            run_id = $runId
            status = "skipped_completed"
            exit_code = 0
            duration_seconds = 0
            report_path = $reportPath
            summary_path = $summaryPath
        })
        continue
    }

    if ($commonRunFolder -and (Test-Path -LiteralPath $commonRunFolder)) {
        Remove-Item -LiteralPath $commonRunFolder -Recurse -Force
    }
    if ($reportPath) {
        $reportDir = Split-Path -Parent $reportPath
        $reportBase = [System.IO.Path]::GetFileNameWithoutExtension($reportPath)
        if (Test-Path -LiteralPath $reportDir) {
            Get-ChildItem -LiteralPath $reportDir -Filter "$reportBase*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }

    Write-BatchLog "[$index/$($runs.Count)] RUN run_id=$runId scenario=$scenarioName variant=$($run.variant)"
    $started = Get-Date
    $output = @()
    $exitCode = 0
    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts\backtest.ps1") -TerminalPath $TerminalPath -ConfigPath $iniPath -TimeoutSeconds $TimeoutSecondsPerRun -RestartExisting 2>&1
        $exitCode = $LASTEXITCODE
    } catch {
        $exitCode = 1
        $output += $_.Exception.Message
    }
    foreach ($line in $output) {
        Add-Content -LiteralPath $batchLogPath -Value ("    " + [string]$line) -Encoding UTF8
    }
    $ended = Get-Date
    $duration = [int]($ended - $started).TotalSeconds
    $summaryPath = Resolve-EaCsvPath -Folder $commonRunFolder -ScenarioName $scenarioName -Suffix "summary"
    $complete = Test-RunComplete -ReportPath $reportPath -SummaryPath $summaryPath
    $status = if ($exitCode -eq 0 -and $complete) {
        "completed"
    } elseif ($exitCode -eq 0) {
        "completed_missing_artifacts"
    } else {
        "failed"
    }
    Write-BatchLog "[$index/$($runs.Count)] $status run_id=$runId exit=$exitCode duration=${duration}s"
    Append-Status ([pscustomobject]@{
        timestamp = (Get-Date).ToString("o")
        run_index = $index
        run_id = $runId
        status = $status
        exit_code = $exitCode
        duration_seconds = $duration
        report_path = $reportPath
        summary_path = $summaryPath
    })
}

if ($AnalyzeWhenDone) {
    Write-BatchLog "Running M15 anchor first-break analysis script."
    $analysisOutput = & python (Resolve-RepoPath $AnalysisScript) 2>&1
    foreach ($line in $analysisOutput) {
        Add-Content -LiteralPath $batchLogPath -Value ("    " + [string]$line) -Encoding UTF8
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Analysis failed with exit code $LASTEXITCODE. See $batchLogPath"
    }
}

Write-BatchLog "Batch finished. status=$statusPath log=$batchLogPath"
