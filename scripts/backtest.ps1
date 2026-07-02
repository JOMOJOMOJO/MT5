param(
    [string]$TerminalPath = $env:MT5_TERMINAL,
    [string]$ConfigPath,
    [int]$TimeoutSeconds = 180,
    [switch]$RestartExisting,
    [switch]$AllowTerminalAlgoTrading
)

function Get-ConfigValue {
    param(
        [string[]]$Lines,
        [string]$Key
    )

    $line = $Lines | Where-Object { $_ -match "^\s*$([regex]::Escape($Key))=" } | Select-Object -First 1
    if (-not $line) {
        return $null
    }
    return ($line -replace "^\s*$([regex]::Escape($Key))=", "").Trim()
}

function Convert-PresetToHashtable {
    param(
        [string]$PresetPath
    )

    $values = [ordered]@{}
    if (-not $PresetPath -or -not (Test-Path $PresetPath)) {
        return $values
    }

    foreach ($line in Get-Content -Path $PresetPath) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith(";") -or $trimmed.StartsWith("#")) {
            continue
        }
        if ($trimmed -notmatch "=") {
            continue
        }

        $key, $rawValue = $trimmed -split "=", 2
        if (-not $key) {
            continue
        }

        $firstValue = ($rawValue -split "\|\|", 2)[0].Trim()
        $values[$key.Trim()] = $firstValue
    }

    return $values
}

function Set-IniSectionValues {
    param(
        [string[]]$Lines,
        [string]$Section,
        [hashtable]$Values
    )

    $result = New-Object System.Collections.Generic.List[string]
    $inTargetSection = $false
    $sectionFound = $false
    $written = @{}

    function Add-MissingSectionValues {
        param(
            [System.Collections.Generic.List[string]]$Target,
            [hashtable]$AllValues,
            [hashtable]$AlreadyWritten
        )

        foreach ($key in $AllValues.Keys) {
            if (-not $AlreadyWritten.ContainsKey($key)) {
                $Target.Add("$key=$($AllValues[$key])")
                $AlreadyWritten[$key] = $true
            }
        }
    }

    foreach ($line in $Lines) {
        if ($line -match '^\s*\[(.+?)\]\s*$') {
            if ($inTargetSection) {
                Add-MissingSectionValues -Target $result -AllValues $Values -AlreadyWritten $written
            }

            $inTargetSection = ($matches[1] -ieq $Section)
            if ($inTargetSection) {
                $sectionFound = $true
                $written = @{}
            }

            $result.Add($line)
            continue
        }

        if ($inTargetSection -and $line -match '^\s*([^=;#][^=]*?)\s*=') {
            $key = $matches[1].Trim()
            if ($Values.ContainsKey($key)) {
                $result.Add("$key=$($Values[$key])")
                $written[$key] = $true
                continue
            }
        }

        $result.Add($line)
    }

    if ($inTargetSection) {
        Add-MissingSectionValues -Target $result -AllValues $Values -AlreadyWritten $written
    }

    if (-not $sectionFound) {
        if ($result.Count -gt 0 -and $result[$result.Count - 1].Trim()) {
            $result.Add("")
        }
        $result.Add("[$Section]")
        foreach ($key in $Values.Keys) {
            $result.Add("$key=$($Values[$key])")
        }
    }

    return $result.ToArray()
}

function Get-MatchingTerminalProcesses {
    param(
        [string]$ResolvedTerminalPath
    )

    return @(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {
        try {
            $_.Path -eq $ResolvedTerminalPath
        } catch {
            $false
        }
    })
}

function Stop-MatchingTerminalProcesses {
    param(
        [string]$ResolvedTerminalPath
    )

    $running = Get-MatchingTerminalProcesses -ResolvedTerminalPath $ResolvedTerminalPath
    foreach ($runningProcess in $running) {
        Stop-Process -Id $runningProcess.Id -Force
        try {
            Wait-Process -Id $runningProcess.Id -Timeout 15 -ErrorAction SilentlyContinue
        } catch {
        }
    }
    return $running.Count
}

function Wait-ForFreshReport {
    param(
        [string]$ReportPath,
        [object]$PreviousWriteTimeUtc,
        [int]$TimeoutSeconds
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if ($ReportPath -and (Test-Path $ReportPath)) {
            $reportItem = Get-Item $ReportPath
            if (-not $PreviousWriteTimeUtc -or $reportItem.LastWriteTimeUtc -gt $PreviousWriteTimeUtc) {
                return $true
            }
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)

    return $false
}

function Test-DirectoryWritable {
    param(
        [string]$DirectoryPath
    )

    try {
        New-Item -ItemType Directory -Path $DirectoryPath -Force -ErrorAction Stop | Out-Null
        $probePath = Join-Path $DirectoryPath ([System.IO.Path]::GetRandomFileName())
        Set-Content -Path $probePath -Value "" -Encoding ASCII -NoNewline -ErrorAction Stop
        Remove-Item -LiteralPath $probePath -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

function Get-TerminalDataRoots {
    param(
        [string]$PrimaryTerminalDataRoot
    )

    $roots = @()
    if ($PrimaryTerminalDataRoot -and (Test-Path $PrimaryTerminalDataRoot)) {
        $roots += (Resolve-Path $PrimaryTerminalDataRoot).Path
    }

    $appTerminalRoot = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    if (Test-Path $appTerminalRoot) {
        foreach ($terminalRoot in Get-ChildItem -LiteralPath $appTerminalRoot -Directory -ErrorAction SilentlyContinue) {
            $commonConfig = Join-Path $terminalRoot.FullName "config\common.ini"
            if (Test-Path $commonConfig) {
                $roots += $terminalRoot.FullName
            }
        }
    }

    return @($roots | Where-Object { $_ } | Select-Object -Unique)
}

function Set-TerminalAlgoTradingState {
    param(
        [string[]]$TerminalRoots,
        [bool]$Enabled
    )

    $value = if ($Enabled) { "1" } else { "0" }

    foreach ($terminalRoot in $TerminalRoots) {
        $commonConfig = Join-Path $terminalRoot "config\common.ini"
        if (-not (Test-Path $commonConfig)) {
            continue
        }

        $lines = Get-Content -Path $commonConfig
        $updatedLines = Set-IniSectionValues -Lines $lines -Section "Experts" -Values @{
            Enabled = $value
            AllowLiveTrading = $value
        }
        Set-Content -Path $commonConfig -Value $updatedLines -Encoding Default
        if (-not $Enabled) {
            Write-Host "MT5 Algo Trading disabled in: $commonConfig"
        }
    }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$terminalDataRoot = (Resolve-Path (Join-Path $repoRoot "..\..\..")).Path
$repoDefaultTerminalPath = "C:\Program Files\XMTrading MT5 - 2\terminal64.exe"
$legacyDefaultTerminalPath = "C:\Program Files\XMTrading MT5\terminal64.exe"

if (-not $TerminalPath -and (Test-Path $repoDefaultTerminalPath)) {
    $TerminalPath = $repoDefaultTerminalPath
}
if (-not $TerminalPath -and (Test-Path $legacyDefaultTerminalPath)) {
    $TerminalPath = $legacyDefaultTerminalPath
}

if (-not $TerminalPath) {
    throw "Terminal path is not set. Pass -TerminalPath or set MT5_TERMINAL."
}

if (-not (Test-Path $TerminalPath)) {
    throw "MT5 terminal executable was not found at '$TerminalPath'."
}

$resolvedTerminalPath = (Resolve-Path $TerminalPath).Path

if (-not $ConfigPath) {
    $defaultConfig = Join-Path $repoRoot "reports\backtest\tester.ini"
    if (Test-Path $defaultConfig) {
        $ConfigPath = $defaultConfig
    } else {
        throw "No tester config was provided. Pass -ConfigPath or create reports/backtest/tester.ini."
    }
}

$resolvedConfig = (Resolve-Path $ConfigPath).Path
$sourceConfigPath = $resolvedConfig
$configLines = Get-Content -Path $resolvedConfig

$presetSourceLine = $configLines | Where-Object { $_ -match '^\s*PresetSource=' } | Select-Object -First 1
$presetNameLine = $configLines | Where-Object { $_ -match '^\s*PresetName=' } | Select-Object -First 1
$generatedConfigPath = $null
$resolvedPresetPath = $null
$presetName = $null
$presetValue = $null
$effectiveExpertParametersName = $null

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

    $expertValue = Get-ConfigValue -Lines $configLines -Key "Expert"
    if ($expertValue) {
        $effectiveExpertParametersName = [System.IO.Path]::GetFileNameWithoutExtension($expertValue) + ".set"
    }
    if (-not $effectiveExpertParametersName) {
        $effectiveExpertParametersName = $presetName
    }

    $discoveredTerminalPresetTargets = @()
    $appTerminalRoot = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    if ($expertValue -and (Test-Path $appTerminalRoot)) {
        foreach ($terminalRoot in Get-ChildItem -LiteralPath $appTerminalRoot -Directory -ErrorAction SilentlyContinue) {
            $candidateExpertPath = Join-Path $terminalRoot.FullName ("MQL5\Experts\" + $expertValue)
            $candidateTesterProfile = Join-Path $terminalRoot.FullName "MQL5\Profiles\Tester"
            if ((Test-Path $candidateExpertPath) -and (Test-Path (Split-Path -Parent $candidateTesterProfile))) {
                $discoveredTerminalPresetTargets += $candidateTesterProfile
            }
        }
    }

    $candidatePresetTargets = @()
    $candidatePresetTargets += (Join-Path $terminalDataRoot "MQL5\Profiles\Tester")
    foreach ($discoveredPresetTarget in $discoveredTerminalPresetTargets) {
        $candidatePresetTargets += $discoveredPresetTarget
    }
    $candidatePresetTargets += (Join-Path (Split-Path -Parent $resolvedTerminalPath) "Profiles\Tester")
    $candidatePresetTargets = $candidatePresetTargets | Where-Object { $_ } | Select-Object -Unique

    $presetTargets = @()
    foreach ($candidateDir in $candidatePresetTargets) {
        if (Test-DirectoryWritable -DirectoryPath $candidateDir) {
            $presetTargets += $candidateDir
        }
    }

    if ($presetTargets.Count -eq 0) {
        throw "No writable MT5 preset profile directory was available."
    }

    foreach ($presetDir in $presetTargets) {
        $targetPresetPath = Join-Path $presetDir $presetName
        Copy-Item -LiteralPath $resolvedPresetPath -Destination $targetPresetPath -Force -ErrorAction Stop
        Write-Host "Preset copied: $targetPresetPath"
        if ($effectiveExpertParametersName -ne $presetName) {
            $targetEaPresetPath = Join-Path $presetDir $effectiveExpertParametersName
            Copy-Item -LiteralPath $resolvedPresetPath -Destination $targetEaPresetPath -Force -ErrorAction Stop
            Write-Host "EA preset copied: $targetEaPresetPath"
        }
    }

    if ($presetTargets.Count -lt $candidatePresetTargets.Count) {
        Write-Host "Preset copied to writable tester profile directory only."
    }

    $filteredConfigLines = foreach ($line in $configLines) {
        if ($line -match '^\s*PresetSource=' -or $line -match '^\s*PresetName=') {
            continue
        }
        if ($line -match '^\s*ExpertParameters=') {
            "ExpertParameters=$effectiveExpertParametersName"
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
            $filteredConfigLines = @($head + "ExpertParameters=$effectiveExpertParametersName" + $tail)
        } else {
            $filteredConfigLines += "ExpertParameters=$effectiveExpertParametersName"
        }
    }

    $generatedConfigPath = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".ini")
    Set-Content -Path $generatedConfigPath -Value $filteredConfigLines -Encoding UTF8
    $resolvedConfig = $generatedConfigPath
    $configLines = $filteredConfigLines
} elseif (-not ($configLines | Where-Object { $_ -match '^\s*ExpertParameters=' })) {
    Write-Warning "No ExpertParameters or PresetSource was set in '$resolvedConfig'. MT5 may reuse the last tester inputs."
}

if (-not $AllowTerminalAlgoTrading) {
    $configLines = Set-IniSectionValues -Lines $configLines -Section "Experts" -Values @{
        Enabled = "0"
        AllowLiveTrading = "0"
    }

    if (-not $generatedConfigPath) {
        $generatedConfigPath = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".ini")
    }

    Set-Content -Path $generatedConfigPath -Value $configLines -Encoding UTF8
    $resolvedConfig = $generatedConfigPath
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

$shutdownTerminal = Get-ConfigValue -Lines $configLines -Key "ShutdownTerminal"
$runningBeforeLaunch = @(Get-MatchingTerminalProcesses -ResolvedTerminalPath $resolvedTerminalPath)
$effectiveRestartExisting = $RestartExisting

if (-not $effectiveRestartExisting -and $shutdownTerminal -eq "1" -and $runningBeforeLaunch.Count -gt 0) {
    Write-Host "Matching MT5 terminal is already running. Restarting it to ensure /config is applied to a fresh tester session."
    $effectiveRestartExisting = $true
}

if ($effectiveRestartExisting) {
    $stoppedCount = Stop-MatchingTerminalProcesses -ResolvedTerminalPath $resolvedTerminalPath
    if ($stoppedCount -gt 0) {
        Write-Host "Stopped $stoppedCount running MT5 terminal process(es)."
    }
}

$terminalDataRootsForAlgoSwitch = Get-TerminalDataRoots -PrimaryTerminalDataRoot $terminalDataRoot
if (-not $AllowTerminalAlgoTrading) {
    Set-TerminalAlgoTradingState -TerminalRoots $terminalDataRootsForAlgoSwitch -Enabled $false
}

$process = Start-Process -FilePath $resolvedTerminalPath -ArgumentList "/config:$resolvedConfig" -PassThru
$exitCode = $null

$reportReady = $false
if ($expectedReportPath) {
    $reportReady = Wait-ForFreshReport -ReportPath $expectedReportPath -PreviousWriteTimeUtc $previousReportWriteTime -TimeoutSeconds $TimeoutSeconds

    if ($process.HasExited) {
        $exitCode = $process.ExitCode
    }

    if (-not $reportReady) {
        if (-not $process.HasExited) {
            try {
                Wait-Process -Id $process.Id -Timeout 5 -ErrorAction SilentlyContinue
            } catch {
            }
        }
        if ($process.HasExited -and $null -eq $exitCode) {
            $exitCode = $process.ExitCode
        }
        throw "Backtest finished but no fresh report was found at '$expectedReportPath'."
    }
} else {
    try {
        Wait-Process -Id $process.Id -Timeout $TimeoutSeconds -ErrorAction Stop
    } catch {
        throw "Backtest launch did not finish within $TimeoutSeconds seconds."
    }
    $exitCode = $process.ExitCode
}

if ($process.HasExited -and $null -eq $exitCode) {
    $exitCode = $process.ExitCode
}
if ($null -eq $exitCode) {
    $exitCode = 0
}

if ($exitCode -ne 0 -and -not $reportReady) {
    throw "Backtest launch failed with exit code $exitCode."
}
if ($exitCode -ne 0 -and $reportReady) {
    Write-Warning "Terminal returned exit code $exitCode, but a fresh report was generated."
}

if (-not $AllowTerminalAlgoTrading) {
    Set-TerminalAlgoTradingState -TerminalRoots $terminalDataRootsForAlgoSwitch -Enabled $false
}

Write-Host "Backtest launched with config: $resolvedConfig"
if ($generatedConfigPath) {
    Write-Host "Generated config: $generatedConfigPath"
}
if ($reportReady) {
    $reportMetaPath = "$expectedReportPath.meta.json"
    $reportMeta = [ordered]@{
        generated_at = (Get-Date).ToString("o")
        config = [ordered]@{
            source_path = $sourceConfigPath
            resolved_path = $resolvedConfig
            generated_config_path = $generatedConfigPath
        }
        tester = [ordered]@{
            symbol = Get-ConfigValue -Lines $configLines -Key "Symbol"
            period = Get-ConfigValue -Lines $configLines -Key "Period"
            from_date = Get-ConfigValue -Lines $configLines -Key "FromDate"
            to_date = Get-ConfigValue -Lines $configLines -Key "ToDate"
            report_path = $expectedReportPath
        }
        preset = if ($resolvedPresetPath) {
            [ordered]@{
                name = $presetName
                expert_parameters_name = $effectiveExpertParametersName
                source = $presetValue
                resolved_path = $resolvedPresetPath
                parameters = Convert-PresetToHashtable -PresetPath $resolvedPresetPath
            }
        } else {
            $null
        }
    }
    $reportMeta | ConvertTo-Json -Depth 8 | Set-Content -Path $reportMetaPath -Encoding UTF8

    Write-Host "Report: $expectedReportPath"
    Write-Host "Report metadata: $reportMetaPath"
}
