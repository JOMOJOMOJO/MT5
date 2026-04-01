param(
    [string]$ReleaseNotePath = ".company/release/btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2.md",
    [string]$RunJsonPath = "reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-131610-294712-btcusd-20260330-session-meanrev-.json",
    [string]$ForwardGatePath = "reports/forward/2026-03-31-btcusd-session-meanrev-live035-guarded2-forward-gate.json",
    [string]$TelemetrySummaryPath = "reports/telemetry/2026-03-31-btcusd-session-meanrev-live035-guarded2-demo-forward.json",
    [string]$CompileLogPath = "reports/compile/metaeditor.log",
    [string]$PresetPath = "reports/presets/btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2.set",
    [string]$OperatorCommandFileName = "mt5_company_btcusd_20260330_session_meanrev_operator.txt",
    [string]$StatusFileName = "mt5_company_btcusd_20260330_session_meanrev_status.txt",
    [int]$MaxHeartbeatAgeMinutes = 180
)

function Resolve-RepoPath {
    param([string]$PathValue)
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return (Resolve-Path $PathValue).Path
    }
    return (Resolve-Path (Join-Path $workspaceRoot $PathValue)).Path
}

function Add-Check {
    param(
        [System.Collections.Generic.List[object]]$Checks,
        [string]$Name,
        [string]$Status,
        [string]$Detail
    )
    $Checks.Add([pscustomobject]@{
            name = $Name
            status = $Status
            detail = $Detail
        })
}

function Get-FirstRegexNumber {
    param(
        [string]$Content,
        [string]$Pattern
    )
    $match = [regex]::Match($Content, $Pattern)
    if (-not $match.Success) {
        return $null
    }
    return [double]$match.Groups[1].Value
}

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$commonFilesPath = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"

$checks = [System.Collections.Generic.List[object]]::new()

$releasePath = Resolve-RepoPath $ReleaseNotePath
$runPath = Resolve-RepoPath $RunJsonPath
$gatePath = Resolve-RepoPath $ForwardGatePath
$telemetryPath = Resolve-RepoPath $TelemetrySummaryPath
$compilePath = Resolve-RepoPath $CompileLogPath
$presetResolvedPath = Resolve-RepoPath $PresetPath
$operatorCommandPath = Join-Path $commonFilesPath $OperatorCommandFileName
$statusPath = Join-Path $commonFilesPath $StatusFileName

Add-Check -Checks $checks -Name "release_note" -Status "pass" -Detail $releasePath
Add-Check -Checks $checks -Name "preset" -Status "pass" -Detail $presetResolvedPath

$compileTail = (Get-Content -Tail 5 $compilePath) -join "`n"
if ($compileTail -match "Result:\s+0 errors,\s+0 warnings") {
    Add-Check -Checks $checks -Name "compile" -Status "pass" -Detail "compile log reports 0 errors, 0 warnings"
} else {
    Add-Check -Checks $checks -Name "compile" -Status "fail" -Detail "compile log did not end in a clean result"
}

$runRaw = Get-Content -Raw $runPath
$net = Get-FirstRegexNumber -Content $runRaw -Pattern '"total_net_profit"\s*:\s*([-0-9.]+)'
$pf = Get-FirstRegexNumber -Content $runRaw -Pattern '"profit_factor"\s*:\s*([-0-9.]+)'
$trades = Get-FirstRegexNumber -Content $runRaw -Pattern '"total_trades"\s*:\s*([-0-9.]+)'
$dd = Get-FirstRegexNumber -Content $runRaw -Pattern '"maximal_drawdown_percent"\s*:\s*([-0-9.]+)'

if ($null -eq $net -or $null -eq $pf -or $null -eq $trades -or $null -eq $dd) {
    Add-Check -Checks $checks -Name "actual_mt5" -Status "fail" -Detail "could not extract core metrics from the run artifact"
} elseif ($net -gt 0 -and $pf -ge 1.0 -and $trades -ge 50 -and $dd -le 3.0) {
    Add-Check -Checks $checks -Name "actual_mt5" -Status "pass" -Detail "net=$net pf=$pf trades=$trades dd=$dd%"
} else {
    Add-Check -Checks $checks -Name "actual_mt5" -Status "fail" -Detail "net=$net pf=$pf trades=$trades dd=$dd%"
}

$gateJson = Get-Content -Raw $gatePath | ConvertFrom-Json
if ($gateJson.baseline_path -eq $gateJson.candidate_path) {
    Add-Check -Checks $checks -Name "forward_gate" -Status "review" -Detail "forward gate is still based on the baseline self-check; real demo-forward evidence is not loaded yet"
} elseif ($gateJson.status -eq "pass") {
    Add-Check -Checks $checks -Name "forward_gate" -Status "pass" -Detail "forward gate status is pass"
} elseif ($gateJson.status -eq "review") {
    Add-Check -Checks $checks -Name "forward_gate" -Status "review" -Detail "forward gate status is review"
} else {
    Add-Check -Checks $checks -Name "forward_gate" -Status "fail" -Detail "forward gate status is $($gateJson.status)"
}

$telemetryJson = Get-Content -Raw $telemetryPath | ConvertFrom-Json
$telemetryPf = [double]$telemetryJson.exits.profit_factor
$telemetryExits = [int]$telemetryJson.exits.count
$telemetrySpreadBlocks = [int]$telemetryJson.daily.blocked_totals.blocked_spread
if ($telemetryPf -ge 1.0 -and $telemetryExits -ge 5) {
    Add-Check -Checks $checks -Name "telemetry_baseline" -Status "pass" -Detail "pf=$telemetryPf exits=$telemetryExits blocked_spread=$telemetrySpreadBlocks"
} else {
    Add-Check -Checks $checks -Name "telemetry_baseline" -Status "fail" -Detail "pf=$telemetryPf exits=$telemetryExits blocked_spread=$telemetrySpreadBlocks"
}

if (Test-Path $operatorCommandPath) {
    $operatorMode = (Get-Content -Raw $operatorCommandPath).Trim()
    if ($operatorMode -eq "flatten") {
        Add-Check -Checks $checks -Name "operator_mode" -Status "review" -Detail "operator mode is flatten"
    } else {
        Add-Check -Checks $checks -Name "operator_mode" -Status "pass" -Detail "operator mode is $operatorMode"
    }
} else {
    Add-Check -Checks $checks -Name "operator_mode" -Status "review" -Detail "operator command file missing"
}

if (Test-Path $statusPath) {
    $statusMap = [ordered]@{}
    foreach ($line in Get-Content -Path $statusPath) {
        if ($line -match "=") {
            $key, $value = $line -split "=", 2
            $statusMap[$key.Trim()] = $value.Trim()
        }
    }
    $entryState = if ($statusMap.Contains("entry_state")) { $statusMap["entry_state"] } else { "" }
    $spreadPips = if ($statusMap.Contains("spread_pips")) { $statusMap["spread_pips"] } else { "" }
    $timestampRaw = if ($statusMap.Contains("timestamp")) { $statusMap["timestamp"] } else { "" }
    $heartbeatStatus = "pass"
    $heartbeatDetail = "entry_state=$entryState spread_pips=$spreadPips"
    if ($timestampRaw) {
        try {
            $heartbeatTimestamp = [datetime]::ParseExact($timestampRaw, "yyyy.MM.dd HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)
            $heartbeatAgeMinutes = [math]::Round(((Get-Date) - $heartbeatTimestamp).TotalMinutes, 1)
            if ($heartbeatAgeMinutes -gt $MaxHeartbeatAgeMinutes) {
                $heartbeatStatus = "review"
            }
            $heartbeatDetail = "entry_state=$entryState spread_pips=$spreadPips timestamp=$timestampRaw age_min=$heartbeatAgeMinutes"
        } catch {
            $heartbeatStatus = "review"
            $heartbeatDetail = "entry_state=$entryState spread_pips=$spreadPips timestamp_unparsed=$timestampRaw"
        }
    } else {
        $heartbeatStatus = "review"
        $heartbeatDetail = "entry_state=$entryState spread_pips=$spreadPips timestamp missing"
    }
    Add-Check -Checks $checks -Name "status_heartbeat" -Status $heartbeatStatus -Detail $heartbeatDetail
} else {
    Add-Check -Checks $checks -Name "status_heartbeat" -Status "review" -Detail "status heartbeat file missing"
}

$statuses = $checks | Select-Object -ExpandProperty status
$overall = if ($statuses -contains "fail") {
    "fail"
} elseif ($statuses -contains "review") {
    "review"
} else {
    "pass"
}

Write-Host "Live Preflight: $overall"
foreach ($check in $checks) {
    Write-Host ("- [{0}] {1}: {2}" -f $check.status.ToUpper(), $check.name, $check.detail)
}
