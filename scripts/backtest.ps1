param(
    [string]$TerminalPath = $env:MT5_TERMINAL,
    [string]$ConfigPath,
    [int]$TimeoutSeconds = 180,
    [switch]$RestartExisting
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$terminalDataRoot = (Resolve-Path (Join-Path $repoRoot "..\..\..")).Path

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
$configLines = Get-Content -Path $resolvedConfig
$reportLine = $configLines | Where-Object { $_ -match '^\s*Report=' } | Select-Object -First 1
$expectedReportPath = $null

if ($reportLine) {
    $reportValue = ($reportLine -replace '^\s*Report=', '').Trim()
    if ($reportValue) {
        if (-not [System.IO.Path]::GetExtension($reportValue)) {
            $reportValue = "$reportValue.htm"
        }

        if ([System.IO.Path]::IsPathRooted($reportValue)) {
            $expectedReportPath = $reportValue
        } else {
            $expectedReportPath = Join-Path $terminalDataRoot $reportValue
        }
    }
}

$previousReportWriteTime = if ($expectedReportPath -and (Test-Path $expectedReportPath)) {
    (Get-Item $expectedReportPath).LastWriteTimeUtc
} else {
    $null
}

if ($RestartExisting) {
    $resolvedTerminalPath = (Resolve-Path $TerminalPath).Path
    $running = Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {
        $_.Path -eq $resolvedTerminalPath
    }
    foreach ($process in $running) {
        Stop-Process -Id $process.Id -Force
        $process.WaitForExit()
    }
}

$process = Start-Process -FilePath $TerminalPath -ArgumentList "/config:$resolvedConfig" -Wait -PassThru
$exitCode = $process.ExitCode

if ($exitCode -ne 0) {
    throw "Backtest launch failed with exit code $exitCode."
}

$reportReady = $false
if ($expectedReportPath) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (Test-Path $expectedReportPath) {
            $reportItem = Get-Item $expectedReportPath
            if (-not $previousReportWriteTime -or $reportItem.LastWriteTimeUtc -gt $previousReportWriteTime) {
                $reportReady = $true
                break
            }
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)

    if (-not $reportReady) {
        throw "Backtest finished but no fresh report was found at '$expectedReportPath'."
    }
}

Write-Host "Backtest launched with config: $resolvedConfig"
if ($reportReady) {
    Write-Host "Report: $expectedReportPath"
}
