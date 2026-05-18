# 2026-05-14 - ExpectedValue NWave USDJPY OOS 3M

## Setup

- EA: `ExpectedValue_NWave_Scalper`
- Symbol: `USDJPY`
- Period: `M5`
- Window: `2025.12.31` to `2026.03.30`
- Mode: `EnableTrading=false` virtual execution
- Context/Pattern/Entry TF: `H4 / M15 / M5`
- Extension filter: `FILTER_ALL`
- Conservative same-bar exit: `true`

## Artifacts

- MT5 report: `reports/backtest/imported/ExpectedValue_NWave_Scalper-usdjpy-oos-3m.htm`
- MT5 metadata: `reports/backtest/imported/ExpectedValue_NWave_Scalper-usdjpy-oos-3m.htm.meta.json`
- Tester config: `reports/backtest/ExpectedValue_NWave_Scalper-usdjpy-oos-3m.ini`
- Preset: `reports/presets/ExpectedValue_NWave_Scalper-usdjpy-oos-3m.set`
- Diagnostics CSV: `reports/backtest/runs/2026-05-14-expected-value-nwave-usdjpy-oos-3m/diagnostics.csv`
- Summary CSV: `reports/backtest/runs/2026-05-14-expected-value-nwave-usdjpy-oos-3m/summary.csv`

## Result

- Closed virtual trades: `194`
- Virtual entries: `195`
- Open at test end: `1`
- Rejected candidates: `696`
- Win rate: `38.14%`
- AvgWinR: `1.5000`
- AvgLossR: `-1.0000`
- ExpectancyR: `-0.0464`
- ProfitFactor: `0.9250`
- Max consecutive losses: `11`
- MaxDD_R: `24.99`
- Long trades: `102`, LongExpectancyR: `-0.0195`
- Short trades: `92`, ShortExpectancyR: `-0.0762`

## Reject Counts

- `max_positions_blocked`: `554`
- `consecutive_loss_blocked`: `97`
- `spread_too_wide`: `36`
- `fibo_filter_failed`: `9`

## Read

- This run does not show positive expectancy under the initial default rules.
- The strategy generated enough closed virtual trades for diagnostics, but the loss streak profile is not acceptable for promotion.
- The largest rejection bucket is `max_positions_blocked`, so the single-position constraint is strongly shaping inventory and should be considered when interpreting missed candidates.
