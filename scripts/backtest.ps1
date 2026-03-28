param(
    [string]$TerminalPath = $env:MT5_TERMINAL,
    [string]$ConfigPath
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if (-not $TerminalPath) {
    throw "Terminal path is not set. Pass -TerminalPath or set MT5_TERMINAL."
}

if (-not (Test-Path $TerminalPath)) {
    throw "MT5 terminal executable was not found at '$TerminalPath'."
}

if (-not $ConfigPath) {
    $defaultConfig = Join-Path $repoRoot "reports\backtest\tester.ini"
    if (Test-Path $defaultConfig) {
        $ConfigPath = $defaultConfig
    } else {
        throw "No tester config was provided. Pass -ConfigPath or create reports/backtest/tester.ini."
    }
}

$resolvedConfig = (Resolve-Path $ConfigPath).Path

& $TerminalPath "/config:$resolvedConfig"
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    throw "Backtest launch failed with exit code $exitCode."
}

Write-Host "Backtest launched with config: $resolvedConfig"
