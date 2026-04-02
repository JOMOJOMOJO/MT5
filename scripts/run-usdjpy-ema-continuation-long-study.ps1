param(
  [string]$TerminalPath = "C:\Program Files\XMTrading MT5\terminal64.exe",
  [string]$Symbol = "USDJPY",
  [string]$Timeframe = "M15",
  [int]$AnalysisDays = 365,
  [int]$OosDays = 89,
  [double]$StopLossPips = 15.0,
  [double]$TargetR = 1.2,
  [int]$MaxHoldBars = 12,
  [double]$TargetTradesPerDay = 1.0
)

$scriptPath = Join-Path $PSScriptRoot "..\plugins\mt5-company\scripts\usdjpy_ema_continuation_long_event_study.py"
$scriptPath = [System.IO.Path]::GetFullPath($scriptPath)

python $scriptPath `
  --terminal-path $TerminalPath `
  --symbol $Symbol `
  --timeframe $Timeframe `
  --analysis-days $AnalysisDays `
  --oos-days $OosDays `
  --stop-loss-pips $StopLossPips `
  --target-r $TargetR `
  --max-hold-bars $MaxHoldBars `
  --target-trades-per-day $TargetTradesPerDay
