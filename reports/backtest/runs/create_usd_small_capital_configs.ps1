$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path '.').Path
$runRoot = Join-Path $repo 'reports/backtest/runs/2026-05-18-expected-value-nwave-g039-usd-small-capital'
$presetDir = Join-Path $runRoot 'presets'
$iniDir = Join-Path $runRoot 'ini'
$rawDir = Join-Path $runRoot 'raw'
New-Item -ItemType Directory -Force -Path $presetDir,$iniDir,$rawDir,'reports/presets' | Out-Null
$base = Join-Path $repo 'reports/backtest/runs/2026-05-15-expected-value-nwave-g039-production-ops/presets/g039_production_guard_2026_jan_apr.set'
$baseLines = Get-Content $base
function Write-SetFile {
  param([string]$Path, [System.Collections.Specialized.OrderedDictionary]$Updates)
  $seen=@{}
  $out=New-Object System.Collections.Generic.List[string]
  foreach($line in $baseLines){
    if($line.Trim().StartsWith(';') -or $line -notmatch '='){ continue }
    $key=($line -split '=',2)[0]
    if($Updates.Contains($key)){ $out.Add("$key=$($Updates[$key])"); $seen[$key]=$true }
    else { $out.Add($line) }
  }
  foreach($key in $Updates.Keys){ if(-not $seen.ContainsKey($key)){ $out.Add("$key=$($Updates[$key])") } }
  Set-Content -Path $Path -Value $out -Encoding ASCII
}
function New-Ini {
  param([string]$Name,[string]$SetName,[string]$From,[string]$To,[int]$Deposit)
  $ini=Join-Path $iniDir "$Name.ini"
  @('[Tester]',
    'Expert=dev\mql\Experts\ExpectedValue_NWave_Scalper.ex5',
    "ExpertParameters=$SetName",
    'Symbol=USDJPY','Period=M5','Model=4','ExecutionMode=0','Optimization=0','OptimizationCriterion=6',
    "FromDate=$From","ToDate=$To",'ForwardMode=0',"Deposit=$Deposit",'Currency=USD','Leverage=1:100','UseLocal=1','UseRemote=0','UseCloud=0','Visual=0','ReplaceReport=1','ShutdownTerminal=1') | Set-Content -Path $ini -Encoding ASCII
  return $ini
}
function OrderedClone($source) {
  $d=[ordered]@{}
  foreach($k in $source.Keys){ $d[$k]=$source[$k] }
  return $d
}
$commonBase=[ordered]@{
  EnableTrading='true||true||0||true||N'
  SelectedStrategyMode='2||2||0||2||N'
  DoubleTopBottomToleranceATR='0.20||0.20||0.05||0.80||N'
  NecklineBreakBufferATR='0.07||0.07||0.00||0.30||N'
  ADXLowThreshold='22.0||22.0||10.0||30.0||N'
  ADXHighThreshold='32.0||32.0||20.0||50.0||N'
  TakeProfitRMultiple='1.5||1.5||1.0||3.0||N'
  ExitSimulationModeInput='0||0||0||7||N'
  ConservativeSameBarExit='true||true||0||true||N'
  MaxSpreadPoints='30.0||30.0||5.0||200.0||N'
  UseEquityCurveGuard='true||true||0||true||N'
  AllowOnlyOnePositionForStrategy01B='true||true||0||true||N'
  MaxManagedPositions='2||2||1||20||N'
  MaxConsecutiveLosses='0||0||0||20||N'
  DailyMaxLossPercent='0.0||0.0||0.0||10.0||N'
  MaxDailyLossR='999.0||999.0||0.0||999.0||N'
  MaxWeeklyLossR='999.0||999.0||0.0||999.0||N'
  MaxMonthlyLossR='999.0||999.0||0.0||999.0||N'
  StopTradingAfterMaxDD_R='999.0||999.0||0.0||999.0||N'
  InpBlockUnsafeForwardDemoSettings='true||true||0||true||N'
  InpBlockNonDemoAccountForForwardDemo='true||true||0||true||N'
  InpUseDrawdownPercentGuards='false||false||0||true||N'
  InpUseSmallCapitalChallengeMode='false||false||0||true||N'
  SmallCapitalRequireUsdAccount='true||true||0||true||N'
  SmallCapitalUseEquityInsteadOfBalance='true||true||0||true||N'
  SmallCapitalTier1EquityUsd='1000.0||1000.0||100.0||5000.0||N'
  SmallCapitalTier2EquityUsd='10000.0||10000.0||1000.0||50000.0||N'
  SmallCapitalMaxEffectiveRiskPercent='15.0||15.0||1.0||50.0||N'
  SmallCapitalAllowMinLotOverride='true||true||0||true||N'
  SmallCapitalBlockIfEffectiveRiskTooHigh='true||true||0||true||N'
  SmallCapitalUseChallengeDDGuards='true||true||0||true||N'
  SmallCapitalSoftPauseDDPercent='40.0||40.0||0.0||100.0||N'
  SmallCapitalHardStopDDPercent='70.0||70.0||0.0||100.0||N'
  SmallCapitalRuinDDPercent='95.0||95.0||0.0||100.0||N'
  DrawObjects='false||false||0||true||N'
  LogToCSV='true||true||0||true||N'
  DebugMode='false||false||0||true||N'
  InpResetDrawdownGuardState='true||true||0||true||N'
  MinBarsBetweenEntries='5||5||0||12||N'
}
$patterns=@(
  [pscustomobject]@{Name='baseline_025'; Risk='0.25||0.25||0.01||2.0||N'; Challenge=$false; T1='10.0||10.0||1.0||20.0||N'; T2='5.0||5.0||1.0||10.0||N'; T3='1.0||1.0||0.1||5.0||N'; MaxOpen='15.0||15.0||0.0||100.0||N'},
  [pscustomobject]@{Name='ladder_10_5_1'; Risk='0.25||0.25||0.01||20.0||N'; Challenge=$true; T1='10.0||10.0||1.0||20.0||N'; T2='5.0||5.0||1.0||10.0||N'; T3='1.0||1.0||0.1||5.0||N'; MaxOpen='15.0||15.0||0.0||100.0||N'},
  [pscustomobject]@{Name='safer_5_2_1'; Risk='0.25||0.25||0.01||20.0||N'; Challenge=$true; T1='5.0||5.0||1.0||20.0||N'; T2='2.0||2.0||1.0||10.0||N'; T3='1.0||1.0||0.1||5.0||N'; MaxOpen='15.0||15.0||0.0||100.0||N'}
)
$periods=@(
  [pscustomobject]@{Name='2025'; From='2025.01.01'; To='2025.12.31'},
  [pscustomobject]@{Name='2026_jan_apr'; From='2026.01.01'; To='2026.04.30'},
  [pscustomobject]@{Name='2024_2026'; From='2024.01.01'; To='2026.04.30'}
)
$deposits=@(100,500,1000,10000)
$manifest=@()
$magic=2026051800
foreach($dep in $deposits){
  foreach($pat in $patterns){
    $updates=OrderedClone $commonBase
    $updates.RiskPercent=$pat.Risk
    $updates.MaxTotalOpenRiskPercent=$pat.MaxOpen
    $updates.InpUseSmallCapitalChallengeMode=$(if($pat.Challenge){'true||true||0||true||N'}else{'false||false||0||true||N'})
    $updates.SmallCapitalTier1RiskPercent=$pat.T1
    $updates.SmallCapitalTier2RiskPercent=$pat.T2
    $updates.SmallCapitalTier3RiskPercent=$pat.T3
    foreach($period in $periods){
      $magic++
      $name="g039_usd_small_${dep}_$($pat.Name)_$($period.Name)"
      $updates.MagicNumber="$magic||$magic||1||999999999||N"
      $setName="$name.set"
      $setPath=Join-Path $presetDir $setName
      Write-SetFile -Path $setPath -Updates $updates
      $ini=New-Ini -Name $name -SetName $setName -From $period.From -To $period.To -Deposit $dep
      $manifest += [pscustomobject]@{name=$name; magic=$magic; deposit=$dep; pattern=$pat.Name; period=$period.Name; from=$period.From; to=$period.To; set=$setPath; ini=$ini}
    }
  }
}
$demoUpdates=OrderedClone $commonBase
$demoUpdates.EnableTrading='true||true||0||true||N'
$demoUpdates.MagicNumber='2026051899||2026051899||1||999999999||N'
$demoUpdates.RiskPercent='0.25||0.25||0.01||20.0||N'
$demoUpdates.MaxTotalOpenRiskPercent='15.0||15.0||0.0||100.0||N'
$demoUpdates.InpUseSmallCapitalChallengeMode='true||true||0||true||N'
$demoUpdates.SmallCapitalTier1RiskPercent='10.0||10.0||1.0||20.0||N'
$demoUpdates.SmallCapitalTier2RiskPercent='5.0||5.0||1.0||10.0||N'
$demoUpdates.SmallCapitalTier3RiskPercent='1.0||1.0||0.1||5.0||N'
$demoPreset=Join-Path $repo 'reports/presets/ExpectedValue_NWave_J_SHORT_g039_usd_small_capital_challenge_demo.set'
Write-SetFile -Path $demoPreset -Updates $demoUpdates
$manifest | Export-Csv -Path (Join-Path $runRoot 'manifest.csv') -NoTypeInformation -Encoding UTF8
$manifest.ini | Set-Content -Path (Join-Path $runRoot 'ini_manifest.txt') -Encoding ASCII
Write-Host "created $($manifest.Count) tester configs under $runRoot"
Write-Host "demo preset: $demoPreset"
