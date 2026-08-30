param([int]$TimeoutSeconds=2400)
$ErrorActionPreference="Stop"
$root=(Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$folder="20260831_ts15f_tail_v1_persistent_context_r3_202503"
$runId="ts15f_context_r3_202503"
$runDir=Join-Path $root "reports\backtest\runs\$folder"
if(Test-Path $runDir){throw "Refusing to overwrite $runDir"}
New-Item -ItemType Directory -Path $runDir|Out-Null
$source=Join-Path $root "mql\Experts\ExpectedValue_MultiCurrency_TickShockResearch.mq5"
$log=Join-Path $root "reports\compile\tick_shock\step15f_march_research_ea.log"
& (Join-Path $root "scripts\compile.ps1") -Source $source -LogPath $log
$ex5=[IO.Path]::ChangeExtension($source,".ex5");$commit=(git -C $root rev-parse HEAD).Trim();$ex5Hash=(Get-FileHash $ex5 -Algorithm SHA256).Hash
$presetName="persistent_context_features.set";$presetPath=Join-Path $runDir $presetName
$preset=@(
"InpSymbols=EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD,USDCHF","InpDetectorVersion=3","InpGridMs=250","InpBaselineMinutes=15","InpBaselineExcludeMs=2000","InpMinBaselineSamples=300",
"InpShockPercentile=99.5","InpMinRobustZ=3.5","InpMinEfficiency=0.65","InpMinMoveSpreadRatio=4.0","InpMinTickIntensityRatio=1.5","InpMaxSpreadMedianRatio=1.5","InpMaxQuoteAgeMs=500","InpNoiseFloorTicks=1.0",
"InpBurstQuietMs=300","InpBurstMaxMs=3000","InpPullbackMinPct=15.0","InpPullbackMaxPct=35.0","InpContinuationInvalidPct=50.0","InpPullbackWaitMs=10000","InpReaccelerationConfirmTicks=2",
"InpRewardRisk=1.2","InpMaxHoldSeconds=120","InpShadowSlippageTicks=1.0","InpShadowExitSlippageTicks=1.0","InpCommissionPerLotRoundTurn=0.0","InpCommissionSource=STEP14R_TESTER_DEAL_FIELDS_OBSERVED_ZERO_LIVE_UNVALIDATED",
"InpCommissionEvidenceStatus=1","InpCommissionSymbolScope=EURUSD_TESTER_ONLY_OTHER_SYMBOLS_UNAVAILABLE","InpCommissionUnit=ACCOUNT_CURRENCY_PER_LOT_ROUND_TURN","InpExecutionMode=1","InpSubmitLatencyMs=0",
"InpTokyoStartHour=0","InpTokyoEndHour=9","InpLondonStartHour=8","InpLondonEndHour=17","InpNewYorkStartHour=13","InpNewYorkEndHour=22","InpRunId=$runId","InpLogFolder=$runId",
"InpResumeRun=false","InpResumeCheckpoint=","InpResumeLastEventSequence=-1","InpResumeCursorMsc=0","InpResearchPeriod=2025-03-01_TO_2025-04-01","InpTesterModel=REAL_TICKS_MODEL_4","InpSourceCommit=$commit","InpEx5Hash=$ex5Hash",
"InpSchemaVersion=tickshock-event-v1+detector-feature-v2+control-v1+funnel-v1+event-response-v1+state-conditioned-response-v1+medium-horizon-response-v1+context-feature-v1","InpEnableDebug=false","InpDebugSymbol=EURUSD","InpDebugMaxMessages=200")
[IO.File]::WriteAllLines($presetPath,$preset,[Text.UTF8Encoding]::new($false))
$configPath=Join-Path $runDir "tester_config.ini";$report="MQL5\Experts\dev\reports\backtest\runs\$folder\tester_report.html"
$config=@("[Experts]","Enabled=0","AllowLiveTrading=0","AllowDllImport=0","Account=0","Profile=0","","[Tester]","Expert=dev\mql\Experts\ExpectedValue_MultiCurrency_TickShockResearch.ex5","PresetSource=reports\backtest\runs\$folder\$presetName","PresetName=$presetName","Symbol=EURUSD","Period=M1","Model=4","ExecutionMode=0","Optimization=0","FromDate=2025.03.01","ToDate=2025.04.01","Deposit=10000","Currency=USD","Leverage=1:100","UseLocal=1","UseRemote=0","UseCloud=0","Visual=0","ReplaceReport=1","ShutdownTerminal=1","Report=$report")
[IO.File]::WriteAllLines($configPath,$config,[Text.UTF8Encoding]::new($false))
Copy-Item $ex5 (Join-Path $runDir "executed_EA.ex5");Copy-Item $log (Join-Path $runDir "compile.log")
[IO.File]::WriteAllText((Join-Path $runDir "run_command.txt"),"powershell -NoProfile -ExecutionPolicy Bypass -File tools/tick_shock/run_step15f_march.ps1 -TimeoutSeconds $TimeoutSeconds`r`n",[Text.UTF8Encoding]::new($false))
& (Join-Path $root "scripts\backtest.ps1") -ConfigPath $configPath -TimeoutSeconds $TimeoutSeconds -RestartExisting
$common=Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\$runId";$prefix="ExpectedValue_MultiCurrency_TickShockResearch_${runId}_"
$suffixes=@("events.csv","trades.csv","summary.csv","symbol_specs.csv","detector_features.csv","control_candidates.csv","control_matches.csv","strategy_funnel.csv","event_response.csv","decision_checkpoint_features.csv","strategy_entry_features.csv","path_class_labels.csv","causal_cluster_features.csv","strategy_executable_first_passage.csv","medium_horizon_episode_summary.csv","medium_horizon_response.csv","medium_horizon_entry_comparison.csv","episode_context_features.csv","matched_control_features.csv")
foreach($suffix in $suffixes){$src=Join-Path $common ($prefix+$suffix);if(-not(Test-Path $src)){throw "Missing $src"};Copy-Item $src (Join-Path $runDir $suffix);if(Test-Path ($src+".runmeta")){Copy-Item ($src+".runmeta") (Join-Path $runDir ($suffix+".runmeta"))}}
$terminalExe="C:\Program Files\XMTrading MT5\terminal64.exe";if(-not(Test-Path $terminalExe)){throw "Missing tester terminal $terminalExe"}
$hashRows=@("source_commit=$commit","source_sha256=$((Get-FileHash $source -Algorithm SHA256).Hash)","ex5_sha256=$ex5Hash","terminal_path=$terminalExe","terminal_sha256=$((Get-FileHash $terminalExe -Algorithm SHA256).Hash)","feature_spec_sha256=074C40B21F804CEDB414FA0C75DD1A101B7DF808F6254000B641C134C282B597","model_family_sha256=29A00C165566C46E7102D6B4C6AC14482DCA88E8F4ABAAB8B5DE2E388A60C338")
[IO.File]::WriteAllLines((Join-Path $runDir "source_hashes.txt"),$hashRows,[Text.UTF8Encoding]::new($false))
Write-Host "Completed $runDir"
