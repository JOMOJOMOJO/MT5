param(
    [ValidateSet("all","strict","raw","robust","persistent")]
    [string]$Only = "all",
    [int]$TimeoutSeconds = 1800
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$eaSource = Join-Path $repoRoot "mql\Experts\ExpectedValue_MultiCurrency_TickShockResearch.mq5"
$eaEx5 = [IO.Path]::ChangeExtension($eaSource,".ex5")
$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()
$ex5Hash = (Get-FileHash -LiteralPath $eaEx5 -Algorithm SHA256).Hash
$runs = @(
    [pscustomobject]@{ Key="strict"; Detector=0; Folder="20260827_ts15a_strict_v0_realizable_202503_r2"; RunId="ts15a_strict_v0_realizable_202503_r2_20260827" },
    [pscustomobject]@{ Key="raw"; Detector=1; Folder="20260827_ts15a_tail_v1_raw_realizable_202503_r2"; RunId="ts15a_tail_v1_raw_realizable_202503_r2_20260827" },
    [pscustomobject]@{ Key="robust"; Detector=2; Folder="20260827_ts15a_tail_v1_noise_robust_realizable_202503_r2"; RunId="ts15a_tail_v1_noise_robust_realizable_202503_r2_20260827" },
    [pscustomobject]@{ Key="persistent"; Detector=3; Folder="20260827_ts15a_tail_v1_persistent_realizable_202503_r2"; RunId="ts15a_tail_v1_persistent_realizable_202503_r2_20260827" }
)
if ($Only -ne "all") { $runs = @($runs | Where-Object Key -eq $Only) }

foreach ($run in $runs) {
    $runDir = Join-Path $repoRoot ("reports\backtest\runs\" + $run.Folder)
    if (Test-Path -LiteralPath $runDir) { throw "Refusing to overwrite existing run: $runDir" }
    New-Item -ItemType Directory -Path $runDir | Out-Null
    $logFolder = $run.RunId
    $presetName = $run.Key + ".set"
    $presetPath = Join-Path $runDir $presetName
    $preset = @(
        "InpSymbols=EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD,USDCHF",
        "InpDetectorVersion=$($run.Detector)",
        "InpGridMs=250",
        "InpBaselineMinutes=15",
        "InpBaselineExcludeMs=2000",
        "InpMinBaselineSamples=300",
        "InpShockPercentile=99.5",
        "InpMinRobustZ=3.5",
        "InpMinEfficiency=0.65",
        "InpMinMoveSpreadRatio=4.0",
        "InpMinTickIntensityRatio=1.5",
        "InpMaxSpreadMedianRatio=1.5",
        "InpMaxQuoteAgeMs=500",
        "InpNoiseFloorTicks=1.0",
        "InpBurstQuietMs=300",
        "InpBurstMaxMs=3000",
        "InpPullbackMinPct=15.0",
        "InpPullbackMaxPct=35.0",
        "InpContinuationInvalidPct=50.0",
        "InpPullbackWaitMs=10000",
        "InpReaccelerationConfirmTicks=2",
        "InpRewardRisk=1.2",
        "InpMaxHoldSeconds=120",
        "InpShadowSlippageTicks=1.0",
        "InpShadowExitSlippageTicks=1.0",
        "InpCommissionPerLotRoundTurn=0.0",
        "InpCommissionSource=STEP14R_TESTER_DEAL_FIELDS_OBSERVED_ZERO_LIVE_UNVALIDATED",
        "InpCommissionEvidenceStatus=1",
        "InpCommissionSymbolScope=EURUSD_TESTER_ONLY_OTHER_SYMBOLS_UNAVAILABLE",
        "InpCommissionUnit=ACCOUNT_CURRENCY_PER_LOT_ROUND_TURN",
        "InpExecutionMode=1",
        "InpSubmitLatencyMs=0",
        "InpTokyoStartHour=0",
        "InpTokyoEndHour=9",
        "InpLondonStartHour=8",
        "InpLondonEndHour=17",
        "InpNewYorkStartHour=13",
        "InpNewYorkEndHour=22",
        "InpRunId=$($run.RunId)",
        "InpLogFolder=$logFolder",
        "InpResumeRun=false",
        "InpResumeCheckpoint=",
        "InpResumeLastEventSequence=-1",
        "InpResumeCursorMsc=0",
        "InpResearchPeriod=2025-03-01_TO_2025-04-01",
        "InpTesterModel=REAL_TICKS_MODEL_4",
        "InpSourceCommit=$sourceCommit",
        "InpEx5Hash=$ex5Hash",
        "InpSchemaVersion=tickshock-event-v1+detector-feature-v1",
        "InpEnableDebug=false",
        "InpDebugSymbol=EURUSD",
        "InpDebugMaxMessages=200"
    )
    [IO.File]::WriteAllLines($presetPath,$preset,[Text.UTF8Encoding]::new($false))
    $configPath = Join-Path $runDir "tester_config.ini"
    $reportRelative = "MQL5\Experts\dev\reports\backtest\runs\$($run.Folder)\tester_report.html"
    $config = @(
        "[Experts]","Enabled=0","AllowLiveTrading=0","AllowDllImport=0","Account=0","Profile=0","",
        "[Tester]","Expert=dev\mql\Experts\ExpectedValue_MultiCurrency_TickShockResearch.ex5",
        "PresetSource=reports\backtest\runs\$($run.Folder)\$presetName","PresetName=$presetName",
        "Symbol=EURUSD","Period=M1","Model=4","ExecutionMode=0","Optimization=0","OptimizationCriterion=6",
        "FromDate=2025.03.01","ToDate=2025.04.01","ForwardMode=0","Deposit=10000","Currency=USD","Leverage=1:100",
        "UseLocal=1","UseRemote=0","UseCloud=0","Visual=0","ReplaceReport=1","ShutdownTerminal=1","Report=$reportRelative"
    )
    [IO.File]::WriteAllLines($configPath,$config,[Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath $eaEx5 -Destination (Join-Path $runDir "executed_EA.ex5")
    Copy-Item -LiteralPath (Join-Path $repoRoot "reports\compile\tick_shock\step15a_research_ea.log") -Destination (Join-Path $runDir "compile.log")
    $command = "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/backtest.ps1 -ConfigPath reports/backtest/runs/$($run.Folder)/tester_config.ini -TimeoutSeconds $TimeoutSeconds -RestartExisting"
    [IO.File]::WriteAllText((Join-Path $runDir "run_command.txt"),$command+"`r`n",[Text.UTF8Encoding]::new($false))
    & (Join-Path $repoRoot "scripts\backtest.ps1") -ConfigPath $configPath -TimeoutSeconds $TimeoutSeconds -RestartExisting

    $commonFolder = Join-Path $env:APPDATA ("MetaQuotes\Terminal\Common\Files\" + $logFolder)
    $prefix = "ExpectedValue_MultiCurrency_TickShockResearch_$($run.RunId)_"
    foreach ($suffix in @("events.csv","trades.csv","summary.csv","symbol_specs.csv","detector_features.csv")) {
        $source = Join-Path $commonFolder ($prefix+$suffix)
        if (-not (Test-Path -LiteralPath $source)) { throw "Missing EA artifact: $source" }
        Copy-Item -LiteralPath $source -Destination (Join-Path $runDir $suffix)
        $metadata = $source+".runmeta"
        if (Test-Path -LiteralPath $metadata) { Copy-Item -LiteralPath $metadata -Destination (Join-Path $runDir ($suffix+".runmeta")) }
    }
    Write-Host "Completed Step 15A run: $($run.Folder)"
}
