param(
    [string]$TerminalPath = "C:\Program Files\XMTrading MT5 - 2\terminal64.exe",
    [int]$TimeoutSecondsPerRun = 2700,
    [int]$StartAt = 1,
    [int]$Limit = 0,
    [switch]$Force,
    [switch]$AnalyzeWhenDone
)

$ErrorActionPreference = "Stop"
$runner = Join-Path $PSScriptRoot "run-session-reversal-m15-anchor-first-break-batch.ps1"
$arguments = @{
    TerminalPath = $TerminalPath
    MatrixPath = "reports\backtest\runs\20260711_session_reversal_m5_micro_n_relaunch\run_matrix.csv"
    RunRootPath = "reports\backtest\runs\20260711_session_reversal_m5_micro_n_relaunch"
    AnalysisScript = "scripts\analyze-session-reversal-m5-micro-n-relaunch-cycles.py"
    TimeoutSecondsPerRun = $TimeoutSecondsPerRun
    StartAt = $StartAt
    Limit = $Limit
    Force = $Force
    AnalyzeWhenDone = $AnalyzeWhenDone
}
& $runner @arguments
exit $LASTEXITCODE
