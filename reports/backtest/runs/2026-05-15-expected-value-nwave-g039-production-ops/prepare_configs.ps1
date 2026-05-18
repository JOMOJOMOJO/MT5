$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$runRoot = $PSScriptRoot
$presetDir = Join-Path $runRoot 'presets'
$iniDir = Join-Path $runRoot 'ini'
$rawDir = Join-Path $runRoot 'raw'
New-Item -ItemType Directory -Force -Path $presetDir, $iniDir, $rawDir | Out-Null

$baseSet = Join-Path $repo 'reports/backtest/runs/2026-05-15-expected-value-nwave-j-short-livepath-2025-is-oos/presets/livepath_oos2026_jshort_top4_g039_tol0.20_neck0.07_adx22_32.set'
$baseLines = Get-Content -Path $baseSet

function Write-SetFile {
    param(
        [string]$Path,
        [hashtable]$Updates
    )

    $seen = @{}
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($line in $baseLines) {
        if ($line.Trim().StartsWith(';') -or $line -notmatch '=') {
            $out.Add($line)
            continue
        }

        $key = ($line -split '=', 2)[0]
        if ($Updates.ContainsKey($key)) {
            $seen[$key] = $true
            $out.Add("$key=$($Updates[$key])")
        } else {
            $out.Add($line)
        }
    }

    foreach ($key in (@($Updates.Keys) | Sort-Object)) {
        if (-not $seen.ContainsKey($key)) {
            $out.Add("$key=$($Updates[$key])")
        }
    }

    Set-Content -Path $Path -Value $out -Encoding ASCII
}

function New-TesterIni {
    param(
        [string]$Name,
        [string]$PresetPath,
        [string]$From,
        [string]$To,
        [string]$ReportPath
    )

    $presetName = Split-Path $PresetPath -Leaf
    $resolvedPreset = (Resolve-Path $PresetPath).Path
    $relPreset = $resolvedPreset.Substring($repo.Length).TrimStart('\', '/') -replace '\\', '/'
    $lines = @(
        '[Tester]',
        'Expert=dev\mql\Experts\ExpectedValue_NWave_Scalper.ex5',
        "ExpertParameters=$presetName",
        "PresetSource=$relPreset",
        "PresetName=$presetName",
        'Symbol=USDJPY',
        'Period=M5',
        'Model=4',
        'ExecutionMode=0',
        'Optimization=0',
        'OptimizationCriterion=6',
        "FromDate=$From",
        "ToDate=$To",
        'ForwardMode=0',
        'Deposit=10000',
        'Currency=USD',
        'Leverage=1:100',
        'UseLocal=1',
        'UseRemote=0',
        'UseCloud=0',
        'Visual=0',
        "Report=$ReportPath",
        'ReplaceReport=1',
        'ShutdownTerminal=1'
    )

    $ini = Join-Path $iniDir "$Name.ini"
    Set-Content -Path $ini -Value $lines -Encoding ASCII
    return $ini
}

$commonParams = @{
    EnableTrading = 'true||true||0||true||N'
    RiskPercent = '0.25||0.25||0.01||2.0||N'
    DrawObjects = 'false||false||0||true||N'
    DebugMode = 'false||false||0||true||N'
    InpResetDrawdownGuardState = 'true||true||0||true||N'
    SoftPauseDrawdownPercent = '8.0||8.0||0.0||50.0||N'
    SoftPauseCooldownDays = '5||5||0||30||N'
    HardStopDrawdownPercent = '12.0||12.0||0.0||50.0||N'
    EmergencyStopDrawdownPercent = '15.0||15.0||0.0||50.0||N'
    RequireManualResetAfterHardStop = 'true||true||0||true||N'
    RequireManualResetAfterEmergencyStop = 'true||true||0||true||N'
}

$rawUpdates = $commonParams.Clone()
@{
    MagicNumber = '2026054101||2026054101||1||999999999||N'
    DailyMaxLossPercent = '0.0||0.0||0.0||10.0||N'
    MaxConsecutiveLosses = '0||0||0||20||N'
    MaxManagedPositions = '10||10||1||20||N'
    MaxTotalOpenRiskPercent = '0.0||0.0||0.0||10.0||N'
    MaxDailyLossR = '999.0||999.0||0.0||999.0||N'
    MaxWeeklyLossR = '999.0||999.0||0.0||999.0||N'
    MaxMonthlyLossR = '999.0||999.0||0.0||999.0||N'
    StopTradingAfterMaxDD_R = '999.0||999.0||0.0||999.0||N'
    UseEquityCurveGuard = 'false||false||0||true||N'
    InpBlockUnsafeForwardDemoSettings = 'false||false||0||true||N'
    InpUseDrawdownPercentGuards = 'false||false||0||true||N'
}.GetEnumerator() | ForEach-Object { $rawUpdates[$_.Key] = $_.Value }

$prodBase = $commonParams.Clone()
@{
    DailyMaxLossPercent = '3.0||3.0||0.0||10.0||N'
    MaxConsecutiveLosses = '3||3||0||20||N'
    MaxManagedPositions = '2||2||1||20||N'
    MaxTotalOpenRiskPercent = '0.25||0.25||0.0||3.0||N'
    MaxDailyLossR = '1.5||1.5||0.0||10.0||N'
    MaxWeeklyLossR = '4.0||4.0||0.0||20.0||N'
    MaxMonthlyLossR = '6.0||6.0||0.0||30.0||N'
    StopTradingAfterMaxDD_R = '999.0||999.0||0.0||999.0||N'
    UseEquityCurveGuard = 'true||true||0||true||N'
    MinBarsBetweenEntries = '5||5||0||12||N'
    AllowOnlyOnePositionForStrategy01B = 'true||true||0||true||N'
    InpBlockUnsafeForwardDemoSettings = 'true||true||0||true||N'
    InpUseDrawdownPercentGuards = 'true||true||0||true||N'
}.GetEnumerator() | ForEach-Object { $prodBase[$_.Key] = $_.Value }

$rawSet = Join-Path $presetDir 'g039_raw_livepath_2024_2026.set'
Write-SetFile $rawSet $rawUpdates

$prod2025 = $prodBase.Clone()
$prod2025.MagicNumber = '2026054102||2026054102||1||999999999||N'
$prod2026 = $prodBase.Clone()
$prod2026.MagicNumber = '2026054103||2026054103||1||999999999||N'
$prodFull = $prodBase.Clone()
$prodFull.MagicNumber = '2026054104||2026054104||1||999999999||N'

$prod2025Set = Join-Path $presetDir 'g039_production_guard_2025.set'
$prod2026Set = Join-Path $presetDir 'g039_production_guard_2026_jan_apr.set'
$prodFullSet = Join-Path $presetDir 'g039_production_guard_2024_2026.set'
Write-SetFile $prod2025Set $prod2025
Write-SetFile $prod2026Set $prod2026
Write-SetFile $prodFullSet $prodFull

$inis = @()
$inis += New-TesterIni 'g039_raw_livepath_2024_2026' $rawSet '2024.01.01' '2026.04.30' (Join-Path $rawDir 'g039_raw_livepath_2024_2026.htm')
$inis += New-TesterIni 'g039_production_guard_2025' $prod2025Set '2025.01.01' '2025.12.31' (Join-Path $rawDir 'g039_production_guard_2025.htm')
$inis += New-TesterIni 'g039_production_guard_2026_jan_apr' $prod2026Set '2026.01.01' '2026.04.30' (Join-Path $rawDir 'g039_production_guard_2026_jan_apr.htm')
$inis += New-TesterIni 'g039_production_guard_2024_2026' $prodFullSet '2024.01.01' '2026.04.30' (Join-Path $rawDir 'g039_production_guard_2024_2026.htm')

$inis | Set-Content (Join-Path $runRoot 'ini_manifest.txt') -Encoding ASCII
Write-Host "created $($inis.Count) ini files under $runRoot"
