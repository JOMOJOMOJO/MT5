# ExpectedValue_MultiCurrency_ScoreScanner - 2025 Backtest Summary

## Test Conditions

- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- Run type: single MT5 Strategy Tester backtest, no optimization
- Virtual trade feature: not added / not used
- Main chart symbol: `USDJPY`
- Test timeframe: `M5`
- Period: `2025.01.01` to `2025.12.31`
- Model: `Every tick based on real ticks`
- History quality: `100% real ticks` in MT5 report
- Initial deposit: `10000 USD`
- Leverage: `1:100`
- Broker/server: `VantageTradingLtd-Live`, build `5833`
- Compile: `0 errors, 0 warnings`

## Input Parameters

- `InpEnableTrading=true`
- `InpSymbols=USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD,XAUUSD`
- `InpScanSeconds=300`
- `InpEntryScoreThreshold=60.0`
- `InpContextTF=PERIOD_H1`
- `InpPatternTF=PERIOD_M15`
- `InpExecutionTF=PERIOD_M5`
- `InpMaxPositions=1`
- `InpMaxSameCurrencyGroupPositions=1`
- `InpRiskPerTradePercent=0.50`
- `InpMaxRiskPerSymbolPercent=1.00`
- `InpMaxTotalOpenRiskPercent=3.00`
- `InpDailyMaxLossPercent=3.00`
- `InpWeeklyMaxLossPercent=6.00`
- `InpMaxDrawdownPercent=10.00`
- `InpMaxSpreadATR=0.20`
- `InpStopATRMultiplier=1.20`
- `InpMinSL_ATR=0.60`
- `InpMaxSL_ATR=2.20`
- `InpRewardR=1.50`
- `InpMaxLotCap=1.00`

## MT5 Report Metrics

| Metric | Value |
|---|---:|
| Total trades | 225 |
| Win rate | 39.11% |
| Profit Factor | 0.93 |
| Expected Payoff | -2.22 |
| Total net profit | -500.21 USD |
| Gross profit | 6,569.98 USD |
| Gross loss | -7,070.19 USD |
| Balance max drawdown | 1,088.88 USD (10.28%) |
| Equity max drawdown | 1,088.88 USD (10.28%) |
| Max consecutive wins | 4 (290.81 USD) |
| Max consecutive losses | 9 (-443.39 USD) |
| Average winning trade | 74.66 USD |
| Average losing trade | -51.61 USD |
| Deals | 450 |

## Long / Short Performance

| Direction | Trades | Win Rate | Net Profit | Profit Factor |
|---|---:|---:|---:|---:|
| LONG | 145 | 41.38% | 28.08 USD | 1.006 |
| SHORT | 80 | 35.00% | -528.29 USD | 0.802 |

## Symbol Performance

| Symbol | Trades | Win Rate | Net Profit | Profit Factor |
|---|---:|---:|---:|---:|
| AUDJPY | 1 | 100.00% | 75.27 USD | n/a |
| EURJPY | 2 | 50.00% | 22.50 USD | 1.427 |
| EURUSD | 2 | 0.00% | -98.94 USD | 0.000 |
| GBPJPY | 7 | 42.86% | 20.71 USD | 1.102 |
| GBPUSD | 4 | 25.00% | -75.95 USD | 0.506 |
| USDJPY | 55 | 36.36% | -266.27 USD | 0.853 |
| XAUUSD | 154 | 40.26% | -177.53 USD | 0.963 |

## Monthly Net Profit

| Month | Net Profit |
|---|---:|
| 2025-01 | 256.71 USD |
| 2025-02 | -756.92 USD |

No trades occurred after `2025.02.25` because the max drawdown stop blocked new entries.

## Risk Stops And Runtime Events

- `max_drawdown_stop`: triggered first at `2025.02.25 03:29:59`; score rows with this flag: `622,650`.
- `daily_loss_stop`: not triggered.
- `weekly_loss_stop`: not triggered.
- `max_positions_reached`: appeared in tester log `5,488` times, mainly while one managed position was already open.
- Order sends: `225`.
- Order rejects / retcode errors / invalid stops / not enough money: none found in tester log.
- `CopyRates` failure / `data_insufficient` / CSV `FileOpen failed`: none found in the completed run.
- Same M5-bar close/open re-entry count from extracted trades: `0`.

## Score CSV Diagnostics

The saved score CSV contains `733,817` symbol-score rows across `74,123` unique tester timestamps.

| Signal / Flag | Rows |
|---|---:|
| `best_candidate` | 104,831 |
| `entry_score_ok` | 259 |
| `below_threshold` | 733,558 |
| `not_best` | 628,986 |

`entry_score_ok` by symbol:

| Symbol | Rows |
|---|---:|
| XAUUSD | 158 |
| USDJPY | 61 |
| GBPJPY | 16 |
| EURJPY | 11 |
| GBPUSD | 7 |
| EURUSD | 4 |
| AUDJPY | 2 |

`entry_score_ok` by direction:

| Direction | Rows |
|---|---:|
| LONG | 156 |
| SHORT | 103 |

## Tick Data Notes

The requested real-tick model was used, but MT5 reported generated fallback ticks for missing or discarded real-tick minutes. The model was not changed to an alternate tester model.

- `USDJPY`: real ticks absent for 39 minutes; real ticks discarded for 4,005 minutes.
- `AUDJPY`: absent 40 minutes; discarded 669 minutes.
- `EURJPY`: absent 40 minutes; discarded 980 minutes.
- `EURUSD`: absent 50 minutes; discarded 1,056 minutes.
- `GBPJPY`: absent 41 minutes; discarded 1,642 minutes.
- `GBPUSD`: absent 39 minutes; discarded 1,312 minutes.
- `XAUUSD`: absent 43 minutes; discarded 6,793 minutes and 4 whole days.
- `AUDUSD`: appeared as an auxiliary/conversion symbol in the tester log; absent 39 minutes and discarded 1,016 minutes.

Final tester log totals:

- Main test: `USDJPY,M5`, `30,214,248` ticks, `74,297` bars.
- All symbols: `262,363,005` total ticks.
- Final balance: `9,499.79 USD`.

## Conclusion

The 2025 single backtest is not a live/demo promotion candidate. The EA traded through the real `CTrade` bridge and produced 225 closed trades, but total expectancy was negative: `PF 0.93`, `Expected Payoff -2.22`, and `-500.21 USD` net result. The drawdown guard stopped new entries on `2025.02.25`, so the system effectively failed within the first two months of the year.

The main weakness is not execution availability; orders were accepted and no trade-send errors were found. The weakness is the current score model and risk gate interaction. `XAUUSD` dominated trade selection, the short side was materially negative, and the max drawdown stop was required to prevent further trading. No logic changes or parameter optimization were made after this result.

## Artifacts

- MT5 report: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_report.html`
- Extracted trades: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_trades.csv`
- Score CSV: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_scores.csv`
- Tester config: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025.ini`
- Preset: `reports/presets/ExpectedValue_MultiCurrency_ScoreScanner_2025.set`
- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner.log`
