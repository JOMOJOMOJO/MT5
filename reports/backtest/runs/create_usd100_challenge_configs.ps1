$ErrorActionPreference = 'Stop'
$Repo = (Get-Location).Path
$RunRoot = Join-Path $Repo 'reports/backtest/runs/2026-05-18-expected-value-nwave-g039-usd100-challenge'
$PresetDir = Join-Path $RunRoot 'presets'
$IniDir = Join-Path $RunRoot 'ini'
$RawDir = Join-Path $RunRoot 'raw'
New-Item -ItemType Directory -Path $PresetDir,$IniDir,$RawDir -Force | Out-Null
$BasePreset = Join-Path $Repo 'reports/presets/ExpectedValue_NWave_J_SHORT_g039_usd_small_capital_challenge_demo.set'
$periods = @(
  @{ name='2025'; from='2025.01.01'; to='2025.12.31' },
  @{ name='2026_jan_apr'; from='2026.01.01'; to='2026.04.30' },
  @{ name='2024_2026'; from='2024.01.01'; to='2026.04.30' }
)
$patterns = @(
  @{ name='fixed_min_lot_001'; usd100=$true; small=$false; useMin=$true; maxLot='0.01'; blockMax=$false; t1='5.0'; t2='2.0'; t3='1.0'; maxTotal='15.0' },
  @{ name='safer_ladder_5_2_1_existing'; usd100=$false; small=$true; useMin=$true; maxLot='0.01'; blockMax=$true; t1='5.0'; t2='2.0'; t3='1.0'; maxTotal='15.0' },
  @{ name='hybrid_usd100'; usd100=$true; small=$false; useMin=$false; maxLot='100.0'; blockMax=$false; t1='5.0'; t2='2.0'; t3='1.0'; maxTotal='15.0' }
)
function Set-LineValue([string]$Text, [string]$Key, [string]$Value, [string]$Tail) {
  if($Text -match "(?m)^$([regex]::Escape($Key))=") {
    return [regex]::Replace($Text, "(?m)^$([regex]::Escape($Key))=.*$", "$Key=$Value$Tail")
  }
  return $Text + "`r`n$Key=$Value$Tail"
}
$manifest = @()
$magic = 2026051901
foreach($pat in $patterns) {
  foreach($period in $periods) {
    $name = "g039_usd100_$($pat.name)_$($period.name)"
    $setPath = Join-Path $PresetDir "$name.set"
    $text = Get-Content -LiteralPath $BasePreset -Raw
    $tailBool = '||true||0||true||N'
    $tailNum = '||0||0||0||N'
    $text = Set-LineValue $text 'MagicNumber' $magic '||2026051901||1||2026051999||N'
    $text = Set-LineValue $text 'EnableTrading' 'true' '||true||0||true||N'
    $text = Set-LineValue $text 'SelectedStrategyMode' '2' '||2||0||2||N'
    $text = Set-LineValue $text 'DoubleTopBottomToleranceATR' '0.20' '||0.20||0.05||0.80||N'
    $text = Set-LineValue $text 'NecklineBreakBufferATR' '0.07' '||0.07||0.00||0.30||N'
    $text = Set-LineValue $text 'ADXLowThreshold' '22.0' '||22.0||10.0||30.0||N'
    $text = Set-LineValue $text 'ADXHighThreshold' '32.0' '||32.0||20.0||50.0||N'
    $text = Set-LineValue $text 'TakeProfitRMultiple' '1.5' '||1.5||0.5||3.0||N'
    $text = Set-LineValue $text 'ExitSimulationModeInput' '0' '||0||0||7||N'
    $text = Set-LineValue $text 'ConservativeSameBarExit' 'true' $tailBool
    $text = Set-LineValue $text 'MaxSpreadPoints' '30.0' '||30.0||5.0||200.0||N'
    $text = Set-LineValue $text 'AllowOnlyOnePositionForStrategy01B' 'true' $tailBool
    $text = Set-LineValue $text 'InpBlockNonDemoAccountForForwardDemo' 'true' $tailBool
    $text = Set-LineValue $text 'InpBlockUnsafeForwardDemoSettings' 'true' $tailBool
    $text = Set-LineValue $text 'RiskPercent' '0.25' '||0.25||0.01||20.0||N'
    $text = Set-LineValue $text 'MaxTotalOpenRiskPercent' $pat.maxTotal '||15.0||0.0||100.0||N'
    $text = Set-LineValue $text 'InpUseSmallCapitalChallengeMode' ($pat.small.ToString().ToLower()) $tailBool
    $text = Set-LineValue $text 'SmallCapitalRequireUsdAccount' 'true' $tailBool
    $text = Set-LineValue $text 'SmallCapitalUseEquityInsteadOfBalance' 'true' $tailBool
    $text = Set-LineValue $text 'SmallCapitalTier1RiskPercent' $pat.t1 '||5.0||1.0||20.0||N'
    $text = Set-LineValue $text 'SmallCapitalTier2RiskPercent' $pat.t2 '||2.0||1.0||10.0||N'
    $text = Set-LineValue $text 'SmallCapitalTier3RiskPercent' $pat.t3 '||1.0||0.1||5.0||N'
    $text = Set-LineValue $text 'SmallCapitalMaxEffectiveRiskPercent' '15.0' '||15.0||1.0||50.0||N'
    $text = Set-LineValue $text 'SmallCapitalBlockIfEffectiveRiskTooHigh' 'true' $tailBool
    $text = Set-LineValue $text 'SmallCapitalAllowMinLotOverride' 'true' $tailBool
    $text = Set-LineValue $text 'SmallCapitalUseChallengeDDGuards' 'true' $tailBool
    $text = Set-LineValue $text 'SmallCapitalSoftPauseDDPercent' '40.0' '||40.0||0.0||100.0||N'
    $text = Set-LineValue $text 'SmallCapitalHardStopDDPercent' '70.0' '||70.0||0.0||100.0||N'
    $text = Set-LineValue $text 'SmallCapitalRuinDDPercent' '95.0' '||95.0||0.0||100.0||N'
    $text = Set-LineValue $text 'InpUseUsd100ChallengeMode' ($pat.usd100.ToString().ToLower()) $tailBool
    $text = Set-LineValue $text 'Usd100ChallengeInitialBalance' '100.0' '||100.0||10.0||1000.0||N'
    $text = Set-LineValue $text 'Usd100UseMinLotOnly' ($pat.useMin.ToString().ToLower()) $tailBool
    $text = Set-LineValue $text 'Usd100MaxLot' $pat.maxLot '||0.01||0.01||100.0||N'
    $text = Set-LineValue $text 'Usd100MaxEffectiveRiskPercent' '10.0' '||10.0||1.0||30.0||N'
    $text = Set-LineValue $text 'Usd100HardBlockEffectiveRiskPercent' '15.0' '||15.0||1.0||50.0||N'
    $text = Set-LineValue $text 'Usd100BlockIfMarginInsufficient' 'true' $tailBool
    $text = Set-LineValue $text 'Usd100BlockIfEffectiveRiskTooHigh' ($pat.blockMax.ToString().ToLower()) $tailBool
    $text = Set-LineValue $text 'Usd100SoftPauseDDPercent' '40.0' '||40.0||0.0||100.0||N'
    $text = Set-LineValue $text 'Usd100HardStopDDPercent' '70.0' '||70.0||0.0||100.0||N'
    $text = Set-LineValue $text 'Usd100RuinDDPercent' '95.0' '||95.0||0.0||100.0||N'
    Set-Content -LiteralPath $setPath -Value $text -Encoding ASCII
    $iniPath = Join-Path $IniDir "$name.ini"
    @"
[Tester]
Expert=dev\mql\Experts\ExpectedValue_NWave_Scalper.ex5
ExpertParameters=$name.set
Symbol=USDJPY
Period=M5
Model=4
ExecutionMode=0
Optimization=0
OptimizationCriterion=6
FromDate=$($period.from)
ToDate=$($period.to)
ForwardMode=0
Deposit=100
Currency=USD
Leverage=1:100
UseLocal=1
UseRemote=0
UseCloud=0
Visual=0
ReplaceReport=1
ShutdownTerminal=1
"@ | Set-Content -LiteralPath $iniPath -Encoding ASCII
    $manifest += [pscustomobject]@{ name=$name; magic=$magic; deposit=100; pattern=$pat.name; period=$period.name; from=$period.from; to=$period.to; set=$setPath; ini=$iniPath }
    $magic++
  }
}
$manifest | Export-Csv -Path (Join-Path $RunRoot 'manifest.csv') -NoTypeInformation -Encoding UTF8
$manifest | ForEach-Object { $_.ini } | Set-Content -Path (Join-Path $RunRoot 'ini_manifest.txt') -Encoding ASCII
Copy-Item -LiteralPath (Join-Path $PresetDir 'g039_usd100_fixed_min_lot_001_2025.set') -Destination (Join-Path $Repo 'reports/presets/ExpectedValue_NWave_J_SHORT_g039_usd100_minlot_challenge_demo.set') -Force
Write-Host "Generated $($manifest.Count) USD100 configs under $RunRoot"
