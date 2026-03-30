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

$presetSourceLine = $configLines | Where-Object { $_ -match '^\s*PresetSource=' } | Select-Object -First 1
$presetNameLine = $configLines | Where-Object { $_ -match '^\s*PresetName=' } | Select-Object -First 1
$generatedConfigPath = $null

if ($presetSourceLine) {
    $presetValue = ($presetSourceLine -replace '^\s*PresetSource=', '').Trim()
    if (-not $presetValue) {
        throw "PresetSource was declared but empty in '$resolvedConfig'."
    }

    $presetPath = if ([System.IO.Path]::IsPathRooted($presetValue)) {
        $presetValue
    } else {
        Join-Path $repoRoot $presetValue
    }
    $resolvedPresetPath = (Resolve-Path $presetPath).Path

    $presetName = if ($presetNameLine) {
        ($presetNameLine -replace '^\s*PresetName=', '').Trim()
    } else {
        [System.IO.Path]::GetFileName($resolvedPresetPath)
    }
    if (-not $presetName) {
        throw "Could not determine preset name for '$resolvedPresetPath'."
    }

    $testerPresetDir = Join-Path $terminalDataRoot "MQL5\Profiles\Tester"
    New-Item -ItemType Directory -Path $testerPresetDir -Force | Out-Null
    $targetPresetPath = Join-Path $testerPresetDir $presetName
    Copy-Item -LiteralPath $resolvedPresetPath -Destination $targetPresetPath -Force

    $filteredConfigLines = foreach ($line in $configLines) {
        if ($line -match '^\s*PresetSource=' -or $line -match '^\s*PresetName=') {
            continue
        }
        if ($line -match '^\s*ExpertParameters=') {
            "ExpertParameters=$presetName"
            continue
        }
        $line
    }

    if (-not ($filteredConfigLines | Where-Object { $_ -match '^\s*ExpertParameters=' })) {
        $testerSectionIndex = [Array]::IndexOf($filteredConfigLines, "[Tester]")
        if ($testerSectionIndex -ge 0) {
            $head = @($filteredConfigLines[0..$testerSectionIndex])
            $tailStart = $testerSectionIndex + 1
            $tail = if ($tailStart -lt $filteredConfigLines.Count) {
                @($filteredConfigLines[$tailStart..($filteredConfigLines.Count - 1)])
            } else {
                @()
            }
            $filteredConfigLines = @($head + "ExpertParameters=$presetName" + $tail)
        } else {
            $filteredConfigLines += "ExpertParameters=$presetName"
        }
    }

    $generatedConfigPath = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".ini")
    Set-Content -Path $generatedConfigPath -Value $filteredConfigLines -Encoding UTF8
    $resolvedConfig = $generatedConfigPath
    $configLines = $filteredConfigLines
} elseif (-not ($configLines | Where-Object { $_ -match '^\s*ExpertParameters=' })) {
    Write-Warning "No ExpertParameters or PresetSource was set in '$resolvedConfig'. MT5 may reuse the last tester inputs."
}

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
if ($generatedConfigPath) {
    Write-Host "Preset-backed generated config: $generatedConfigPath"
}
if ($reportReady) {
    Write-Host "Report: $expectedReportPath"
}
