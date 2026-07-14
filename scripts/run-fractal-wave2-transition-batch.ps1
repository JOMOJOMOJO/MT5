param(
    [string]$TerminalPath = "C:\Program Files\XMTrading MT5 - 2\terminal64.exe",
    [string]$MatrixPath = "reports\backtest\runs\20260711_fractal_wave2_transition\run_matrix.csv",
    [string]$RunRootPath = "reports\backtest\runs\20260711_fractal_wave2_transition",
    [int]$TimeoutSecondsPerRun = 2700,
    [int]$StartAt = 1,
    [int]$Limit = 0,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$terminalDataRoot = (Resolve-Path (Join-Path $repoRoot "..\..\..")).Path
$commonFiles = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$matrix = if ([IO.Path]::IsPathRooted($MatrixPath)) { $MatrixPath } else { Join-Path $repoRoot $MatrixPath }
$runRoot = if ([IO.Path]::IsPathRooted($RunRootPath)) { $RunRootPath } else { Join-Path $repoRoot $RunRootPath }
$statusPath = Join-Path $runRoot "batch_status.csv"
$batchLog = Join-Path $runRoot ("batch_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null

function Log([string]$message) {
    $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $message
    Write-Host $line
    Add-Content -LiteralPath $batchLog -Value $line -Encoding UTF8
}

function RepoPath([string]$value) {
    if ([IO.Path]::IsPathRooted($value)) { return $value }
    return Join-Path $repoRoot $value
}

function IniValue([string]$path, [string]$key) {
    $line = Get-Content -LiteralPath $path | Where-Object { $_ -match "^\s*$([regex]::Escape($key))=" } | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line -replace "^\s*$([regex]::Escape($key))=", "").Trim()
}

function AppendStatus($row) {
    $row | Export-Csv -LiteralPath $statusPath -NoTypeInformation -Append:(Test-Path $statusPath) -Encoding UTF8
}

if (-not (Test-Path -LiteralPath $matrix)) { throw "Matrix not found: $matrix" }
if (-not (Test-Path -LiteralPath $TerminalPath)) { throw "MT5 terminal not found: $TerminalPath" }
$runs = @(Import-Csv -LiteralPath $matrix)
$selected = @($runs | Select-Object -Skip ([Math]::Max(0, $StartAt - 1)))
if ($Limit -gt 0) { $selected = @($selected | Select-Object -First $Limit) }
Log "Starting fractal wave2 transition batch. selected=$($selected.Count) terminal=$TerminalPath"

$index = [Math]::Max(0, $StartAt - 1)
foreach ($run in $selected) {
    $index++
    $ini = RepoPath $run.tester_ini
    $preset = RepoPath $run.preset
    $reportValue = IniValue $ini "Report"
    $report = if ([IO.Path]::IsPathRooted($reportValue)) { $reportValue } else { Join-Path $terminalDataRoot $reportValue }
    $commonRun = Join-Path $commonFiles $run.log_folder
    $summary = Join-Path $commonRun ("fw2t_{0}_summary.csv" -f $run.run_id)
    $complete = (Test-Path -LiteralPath $report) -and (Test-Path -LiteralPath "$report.meta.json") -and (Test-Path -LiteralPath $summary)
    if ($complete -and -not $Force) {
        Log "[$index/$($runs.Count)] SKIP $($run.run_id)"
        AppendStatus ([pscustomobject]@{timestamp=(Get-Date).ToString("o");run_index=$index;run_id=$run.run_id;status="skipped_completed";exit_code=0;duration_seconds=0;report_path=$report;summary_path=$summary})
        continue
    }
    if (Test-Path -LiteralPath $commonRun) { Remove-Item -LiteralPath $commonRun -Recurse -Force }
    $reportDir = Split-Path -Parent $report
    $reportBase = [IO.Path]::GetFileNameWithoutExtension($report)
    if (Test-Path -LiteralPath $reportDir) {
        Get-ChildItem -LiteralPath $reportDir -Filter "$reportBase*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    Log "[$index/$($runs.Count)] RUN $($run.run_id) variant=$($run.variant_name)"
    $started = Get-Date
    $output = @()
    $exitCode = 0
    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts\backtest.ps1") -TerminalPath $TerminalPath -ConfigPath $ini -TimeoutSeconds $TimeoutSecondsPerRun -RestartExisting 2>&1
        $exitCode = $LASTEXITCODE
    } catch {
        $exitCode = 1
        $output += $_.Exception.Message
    }
    foreach ($line in $output) { Add-Content -LiteralPath $batchLog -Value ("    " + [string]$line) -Encoding UTF8 }
    $duration = [int]((Get-Date) - $started).TotalSeconds
    $complete = (Test-Path -LiteralPath $report) -and (Test-Path -LiteralPath "$report.meta.json") -and (Test-Path -LiteralPath $summary)
    $status = if ($exitCode -eq 0 -and $complete) { "completed" } elseif ($exitCode -eq 0) { "completed_missing_artifacts" } else { "failed" }
    Log "[$index/$($runs.Count)] $status $($run.run_id) exit=$exitCode duration=${duration}s"
    AppendStatus ([pscustomobject]@{timestamp=(Get-Date).ToString("o");run_index=$index;run_id=$run.run_id;status=$status;exit_code=$exitCode;duration_seconds=$duration;report_path=$report;summary_path=$summary})
}
Log "Batch finished. status=$statusPath"
