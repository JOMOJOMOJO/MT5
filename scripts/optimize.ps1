param(
    [string]$TerminalPath = $env:MT5_TERMINAL,
    [string]$ConfigPath,
    [int]$TimeoutSeconds = 900,
    [switch]$RestartExisting
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $ConfigPath) {
    $defaultConfig = Join-Path $repoRoot "reports\optimization\optimizer-short.ini"
    if (Test-Path $defaultConfig) {
        $ConfigPath = $defaultConfig
    } else {
        throw "No optimization config was provided. Pass -ConfigPath or create reports/optimization/optimizer-short.ini."
    }
}

$backtestScript = Join-Path $PSScriptRoot "backtest.ps1"
$invokeParams = @{
    TerminalPath   = $TerminalPath
    ConfigPath     = $ConfigPath
    TimeoutSeconds = $TimeoutSeconds
}

if ($RestartExisting) {
    $invokeParams.RestartExisting = $true
}

& $backtestScript @invokeParams
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
