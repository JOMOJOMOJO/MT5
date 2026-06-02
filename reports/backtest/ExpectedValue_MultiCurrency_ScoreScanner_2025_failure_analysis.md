# ExpectedValue_MultiCurrency_ScoreScanner - 2025 Failure Analysis

## Scope

- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- Purpose: explain why the 2025 expectancy is negative, not search for winning settings.
- Logic changes: none. Entry logic, score model, TP/SL, and the `CTrade` bridge were not changed.
- Research change: a separate preset disables daily, weekly, and max-DD stops by setting each threshold to `100000.00`.
- Compile status after the run setup: `0 errors, 0 warnings`.

## Test Conditions

Both runs used the same tester conditions unless noted:

- Period: `2025.01.01` to `2025.12.31`
- Main chart: `USDJPY`
- Timeframe: `M5`
- Model: `Every tick based on real ticks`
- MT5 report history quality: `100% real ticks`
- Initial deposit: `10000 USD`
- Leverage: `1:100`
- Broker/server: `VantageTradingLtd-Live`, build `5833`
- Symbols: `USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD,XAUUSD`
- Trading bridge: real `CTrade`, `InpEnableTrading=true`

Risk-stop difference:

| Run | Daily Stop | Weekly Stop | Max DD Stop |
|---|---:|---:|---:|
| stop-on | 3.00% | 6.00% | 10.00% |
| stop-off research | 100000.00% | 100000.00% | 100000.00% |

## Run Comparison

| Metric | Stop-On | Stop-Off Research |
|---|---:|---:|
| Trades | 225 | 1,692 |
| Win rate | 39.11% | 40.01% |
| Profit Factor | 0.929 | 0.984 |
| Expected Payoff | -2.22 USD | -0.40 USD |
| Net profit | -500.21 USD | -672.91 USD |
| Max balance DD | 1,088.88 USD (10.28%) | 3,752.55 USD (35.44%) |
| Max consecutive losses | 9 | 10 |
| XAUUSD trade share | 68.44% | 72.34% |
| SHORT net profit | -528.29 USD | -3,402.23 USD |
| Same M5-bar reentries | 0 | 0 |

The max-DD stop did not hide a strong recovery. After the stop-on run stopped new entries on `2025.02.25 03:29:59`, the stop-off run took 1,467 additional trades and made another `-172.65 USD`. Late-year recovery existed, especially October to December, but it arrived after a `35.44%` balance drawdown.

## Main Findings

### 1. The Combined Strategy Has No Full-Year Edge

The no-stop run is closer to breakeven than the stopped run on Profit Factor, but still negative:

- `PF 0.984`
- `Expected Payoff -0.40 USD`
- `Net -672.91 USD`
- `Max DD 35.44%`

This is not a capital-survival shape. The DD stop saved the account from continuing into a deep drawdown, but it did not cause the negative expectancy.

### 2. SHORT Is The Primary Losing Branch

Full-year stop-off by direction:

| Direction | Trades | Win Rate | Net | PF |
|---|---:|---:|---:|---:|
| LONG | 1,066 | 42.96% | +2,729.32 USD | 1.109 |
| SHORT | 626 | 34.98% | -3,402.23 USD | 0.799 |

The biggest single cut is not XAUUSD. It is the short side, especially `USDJPY SHORT`:

| Branch | Trades | Net | PF |
|---|---:|---:|---:|
| USDJPY SHORT | 206 | -2,307.74 USD | 0.641 |
| XAUUSD SHORT | 364 | -591.24 USD | 0.933 |
| GBPUSD SHORT | 17 | -327.17 USD | 0.422 |
| EURUSD SHORT | 9 | -170.78 USD | 0.416 |

### 3. XAUUSD Concentration Is A Structural Risk, Not The Main Full-Year Loss Source

Stop-off trade distribution:

- XAUUSD trades: `1,224 / 1,692` (`72.34%`)
- XAUUSD net: `+2,097.29 USD`
- XAUUSD LONG: `+2,688.53 USD`
- XAUUSD SHORT: `-591.24 USD`

XAUUSD carried the strategy in the full-year no-stop run. The problem is that the scanner is not really balanced multi-currency exposure. It is dominated by XAUUSD, while the non-XAU and short branches drag the book down.

### 4. Score Is Not Monotonic

Stop-off result by entry score band:

| Score Band | Trades | Win Rate | Net | PF |
|---|---:|---:|---:|---:|
| 60-65 | 645 | 38.60% | -980.90 USD | 0.941 |
| 65-70 | 528 | 40.34% | -8.21 USD | 0.999 |
| 70-75 | 418 | 44.02% | +1,307.58 USD | 1.135 |
| 75-80 | 64 | 25.00% | -1,046.05 USD | 0.492 |
| 80+ | 37 | 40.54% | +54.67 USD | 1.064 |

The score threshold is not a reliable quality control yet. The `70-75` band worked, but `75-80` was poor. Raising the threshold blindly is not justified.

### 5. Month And Time Clustering Explain The Drawdown

Worst stop-off months:

| Month | Net |
|---|---:|
| 2025-08 | -945.32 USD |
| 2025-02 | -940.98 USD |
| 2025-03 | -648.52 USD |
| 2025-06 | -647.41 USD |

Best stop-off months:

| Month | Net |
|---|---:|
| 2025-10 | +1,297.17 USD |
| 2025-12 | +410.75 USD |
| 2025-11 | +406.68 USD |
| 2025-05 | +325.21 USD |

Worst server-hour buckets:

| Hour | Net |
|---|---:|
| 02 | -682.91 USD |
| 12 | -456.70 USD |
| 07 | -436.53 USD |
| 09 | -434.85 USD |
| 10 | -432.52 USD |
| 23 | -374.24 USD |

Best server-hour buckets:

| Hour | Net |
|---|---:|
| 13 | +754.86 USD |
| 08 | +609.24 USD |
| 06 | +531.98 USD |
| 18 | +485.77 USD |
| 20 | +457.66 USD |

The max balance peak was `10,588.71 USD` on `2025.02.12 18:17:06`. The deepest balance DD was reached at `2025.09.18 05:07:18`, with balance `6,836.16 USD` and drawdown `3,752.55 USD`.

## Runtime And Data Notes

- Stop-off order failures: `615` effective `retcode=10018` market-closed attempts, all `XAUUSD LONG`.
- Dates with market-closed attempts: `2025.05.06`, `2025.05.07`, `2025.08.02`, `2025.08.03`, `2025.08.04`.
- Invalid stops: `0`.
- Not enough money: `0`.
- CopyRates/data-insufficient/FileOpen failures: `0`.
- Daily/weekly/DD stop flags in stop-off score CSV: `0`.
- MT5 still reported real-tick generation fallback for missing/discarded real-tick minutes. XAUUSD had `43` absent real-tick minutes, `6,793` discarded minutes, and `4` whole days discarded. The tester model was not changed.

The market-closed attempts are not the main expectancy cause because they did not create losing trades. They are still a live-readiness defect: the EA needs a tradability/session gate before order send in a later implementation phase.

## Judgement

- Without stops, the strategy does not recover enough. It remains negative and reaches a `35.44%` drawdown.
- The full combined strategy does not currently show tradeable expectancy.
- There are research-worthy sub-branches, especially `LONG` and `XAUUSD LONG`.
- The first branch to cut or isolate is `SHORT`, starting with `USDJPY SHORT`.
- XAUUSD concentration should not be treated as the first culprit; full-year XAUUSD was profitable. The real issue is concentration plus weak non-XAU/short selection.

## Next Phase Candidates

1. Isolate `LONG-only` versus `SHORT-only` as separate research runs. Do not tune parameters until the branch-level expectancy is confirmed.
2. Park or hard-filter `USDJPY SHORT` first in diagnostics, because it explains most of the full-year loss.
3. Split XAUUSD from FX. XAUUSD LONG has positive expectancy, but it should not decide whether the whole multi-currency scanner is healthy.
4. Add a market-open/tradability guard before `CTrade` order send. This addresses the `retcode=10018` market-closed attempts and is an execution-quality fix, not an edge optimization.
5. Recalibrate score components before threshold optimization. The `75-80` score band losing heavily means the score is not monotonic.
6. Study session filters only after branch isolation. The worst hours are visible, but hour filters can easily overfit.
7. Keep the DD stop as a survival guard. It limited the first run, but it should not be used to justify the current edge.

## Artifacts

- Stop-on summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_summary.md`
- Stop-off MT5 report: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_no_stops_report.html`
- Stop-off trades: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_no_stops_trades.csv`
- Stop-off scores: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_no_stops_scores.csv`
- Run comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_failure_run_comparison.csv`
- Symbol aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_failure_by_symbol.csv`
- Direction aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_failure_by_direction.csv`
- Month aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_failure_by_month.csv`
- Hour aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_failure_by_hour.csv`
- Score-band aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_failure_by_score_band.csv`
- Trade/score join: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_failure_trade_join.csv`
- Tester-log diagnostics: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_no_stops_tester_log_diagnostics.csv`
