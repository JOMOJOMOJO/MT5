param(
    [string]$TerminalPath = "C:\Program Files\XMTrading MT5 - 2\terminal64.exe",
    [string]$MatrixPath = "reports\backtest\runs\20260815_trendline_wave2_failure\run_matrix.csv",
    [int]$StartAt = 1,
    [int]$Limit = 0,
    [int]$TimeoutSecondsPerRun = 1800,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$matrix = if ([IO.Path]::IsPathRooted($MatrixPath)) { $MatrixPath } else { Join-Path $repoRoot $MatrixPath }
$runRoot = Split-Path -Parent $matrix
$commonFiles = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$statusPath = Join-Path $runRoot "batch_status.csv"
$batchLog = Join-Path $runRoot ("batch_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

function Log([string]$message) {
    $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $message
    Write-Host $line
    Add-Content -LiteralPath $batchLog -Value $line -Encoding UTF8
}
function RepoPath([string]$value) {
    if ([IO.Path]::IsPathRooted($value)) { return $value }
    return Join-Path $repoRoot $value
}
function Copy-LogFolder([string]$folderName, [string]$targetDir, [string]$prefix) {
    $source = Join-Path $commonFiles $folderName
    if (-not (Test-Path -LiteralPath $source)) { return }
    foreach ($file in Get-ChildItem -LiteralPath $source -File) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $targetDir ($prefix + $file.Name)) -Force
    }
}

if (-not (Test-Path -LiteralPath $matrix)) { throw "Matrix not found: $matrix" }
if (-not (Test-Path -LiteralPath $TerminalPath)) { throw "Terminal not found: $TerminalPath" }
$all = @(Import-Csv -LiteralPath $matrix)
$runs = @($all | Select-Object -Skip ([Math]::Max(0, $StartAt - 1)))
if ($Limit -gt 0) { $runs = @($runs | Select-Object -First $Limit) }
Log "Starting TRENDLINE_WAVE2_FAILURE batch. selected=$($runs.Count) start=$StartAt"

foreach ($run in $runs) {
    $ini = RepoPath $run.tester_ini
    $runDir = Split-Path -Parent $ini
    $report = Join-Path $runDir "report.html"
    if ((Test-Path -LiteralPath $report) -and -not $Force) {
        Log "SKIP $($run.run_id): report exists"
        continue
    }
    Log "RUN $($run.run_id) mode=$($run.mode) period=$($run.from_date)..$($run.to_date) model=$($run.model)"
    $started = Get-Date
    $status = "completed"
    $message = ""
    try {
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts\backtest.ps1") `
            -TerminalPath $TerminalPath -ConfigPath $ini -TimeoutSeconds $TimeoutSecondsPerRun -RestartExisting 2>&1
        $message = ($output -join " | ")
        if (-not (Test-Path -LiteralPath $report)) { $status = "missing_report" }
    } catch {
        $status = "failed"
        $message = $_.Exception.Message
    }
    Copy-LogFolder -folderName $run.log_folder -targetDir $runDir -prefix "new_"
    Copy-LogFolder -folderName $run.legacy_log_folder -targetDir $runDir -prefix "legacy_"
    $seconds = [int]((Get-Date) - $started).TotalSeconds
    [pscustomobject]@{
        timestamp = (Get-Date).ToString("o")
        run_id = $run.run_id
        status = $status
        duration_seconds = $seconds
        report = $report
        message = $message
    } | Export-Csv -LiteralPath $statusPath -NoTypeInformation -Append:(Test-Path $statusPath) -Encoding UTF8
    Log "$status $($run.run_id) duration=${seconds}s"
    if ($status -ne "completed") { throw "Run failed: $($run.run_id): $message" }
}
Log "Batch finished."
