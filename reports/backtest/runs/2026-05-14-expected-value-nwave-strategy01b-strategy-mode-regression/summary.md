# Strategy_01B StrategyMode Regression - USDJPY

- Generated: 2026-05-14
- EA: `ExpectedValue_NWave_Scalper`
- Scope: `SelectedStrategyMode` implementation check for frozen C_SHORT and J_SHORT candidates.
- Test: `USDJPY M5`, `EnableTrading=false`, `H4/M15/M5`, fixed internal `1.5R`, `MaxManagedPositions=2`, conservative same-bar exit enabled.
- New risk-only guards were disabled in these regression presets so this test isolates whether StrategyMode reproduces the prior virtual-filter candidates.
- Full, year, and quarter rows are independent MT5 Strategy Tester executions.

## Full Window Metrics
| Mode | Closed | Win% | AvgWinR | AvgLossR | ExpR | PF | MaxDD_R | MaxLosses | ShortExpR |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| C_SHORT_MODE | 505 | 45.94 | 1.4996 | -1.0000 | 0.1484 | 1.2744 | 16.0048 | 14 | 0.1484 |
| J_SHORT_MODE | 340 | 45.88 | 1.4993 | -1.0000 | 0.1467 | 1.2711 | 11.5070 | 10 | 0.1467 |

## Promotion Criteria Check
| Mode | Trades | ExpR | PF | MaxDD_R | Years+ | Quarters+ | Full Exp/PF | Year Pass | Quarter Pass |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| C_SHORT_MODE | 505 | 0.1484 | 1.2744 | 16.0048 | 3/3 | 9/9 | yes/yes | yes | yes |
| J_SHORT_MODE | 340 | 0.1467 | 1.2711 | 11.5070 | 3/3 | 8/9 | yes/yes | yes | yes |

## Independent Year Metrics
| Mode | Year | Closed | Win% | ExpR | PF | MaxDD_R |
| --- | --- | --- | --- | --- | --- | --- |
| C_SHORT_MODE | 2024 | 284 | 43.31 | 0.0826 | 1.1457 | 16.0024 |
| C_SHORT_MODE | 2025 | 170 | 51.18 | 0.2793 | 1.5720 | 16.0048 |
| C_SHORT_MODE | 2026Q1 | 50 | 44.00 | 0.0999 | 1.1783 | 5.4976 |
| J_SHORT_MODE | 2024 | 191 | 42.41 | 0.0599 | 1.1039 | 11.5070 |
| J_SHORT_MODE | 2025 | 117 | 50.43 | 0.2604 | 1.5254 | 10.0000 |
| J_SHORT_MODE | 2026Q1 | 31 | 51.61 | 0.2898 | 1.5989 | 4.0046 |

## Independent Quarter Metrics
| Mode | Quarter | Closed | Win% | ExpR | PF | MaxDD_R |
| --- | --- | --- | --- | --- | --- | --- |
| C_SHORT_MODE | 2024Q1 | 81 | 46.91 | 0.1726 | 1.3251 | 11.5065 |
| C_SHORT_MODE | 2024Q2 | 100 | 42.00 | 0.0498 | 1.0858 | 16.0024 |
| C_SHORT_MODE | 2024Q3 | 27 | 44.44 | 0.1108 | 1.1995 | 3.5000 |
| C_SHORT_MODE | 2024Q4 | 76 | 40.79 | 0.0198 | 1.0334 | 10.4914 |
| C_SHORT_MODE | 2025Q1 | 33 | 57.58 | 0.4390 | 2.0348 | 5.5000 |
| C_SHORT_MODE | 2025Q2 | 37 | 62.16 | 0.5540 | 2.4641 | 6.0000 |
| C_SHORT_MODE | 2025Q3 | 45 | 48.89 | 0.2219 | 1.4342 | 6.0000 |
| C_SHORT_MODE | 2025Q4 | 55 | 41.82 | 0.0455 | 1.0782 | 16.0000 |
| C_SHORT_MODE | 2026Q1 | 50 | 44.00 | 0.0999 | 1.1783 | 5.4976 |
| J_SHORT_MODE | 2024Q1 | 57 | 47.37 | 0.1835 | 1.3487 | 7.0000 |
| J_SHORT_MODE | 2024Q2 | 62 | 38.71 | -0.0327 | 0.9466 | 11.5070 |
| J_SHORT_MODE | 2024Q3 | 22 | 40.91 | 0.0226 | 1.0383 | 4.0000 |
| J_SHORT_MODE | 2024Q4 | 50 | 42.00 | 0.0500 | 1.0863 | 5.0000 |
| J_SHORT_MODE | 2025Q1 | 24 | 58.33 | 0.4579 | 2.0989 | 5.0000 |
| J_SHORT_MODE | 2025Q2 | 25 | 56.00 | 0.3996 | 1.9083 | 5.0000 |
| J_SHORT_MODE | 2025Q3 | 28 | 46.43 | 0.1605 | 1.2996 | 5.0000 |
| J_SHORT_MODE | 2025Q4 | 40 | 45.00 | 0.1249 | 1.2272 | 10.0000 |
| J_SHORT_MODE | 2026Q1 | 31 | 51.61 | 0.2898 | 1.5989 | 4.0046 |

## Match Check Versus DirectionFilter Runs
| Mode | Trades | PrevTrades | TradesDelta | ExpR | PrevExpR | ExpDelta | PF | PrevPF | PFDelta |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| C_SHORT_MODE | 505 | 505 | 0 | 0.1484 | 0.1484 | 0.0000000000 | 1.2744 | 1.2744 | 0.0000000000 |
| J_SHORT_MODE | 340 | 340 | 0 | 0.1467 | 0.1467 | 0.0000000000 | 1.2711 | 1.2711 | 0.0000000000 |

## Monthly ProfitR - Full Runs
| Month | C_SHORT_MODE | J_SHORT_MODE |
| --- | --- | --- |
| 2024-01 | -1.00 | 0.01 |
| 2024-02 | 9.50 | 6.49 |
| 2024-03 | 5.48 | 3.97 |
| 2024-04 | -12.01 | -9.01 |
| 2024-05 | 15.99 | 5.99 |
| 2024-06 | 0.99 | 0.99 |
| 2024-07 | 2.00 | -1.00 |
| 2024-08 | 3.00 | 3.00 |
| 2024-09 | -2.00 | -1.50 |
| 2024-10 | -7.49 | 1.50 |
| 2024-11 | 8.00 | 5.50 |
| 2024-12 | 0.99 | -4.50 |
| 2025-01 | 11.49 | 7.99 |
| 2025-03 | 3.00 | 3.00 |
| 2025-04 | 1.50 | 1.50 |
| 2025-05 | 14.50 | 7.00 |
| 2025-06 | 4.50 | 1.50 |
| 2025-07 | -0.51 | 1.00 |
| 2025-08 | 10.99 | 5.00 |
| 2025-09 | -0.50 | -1.50 |
| 2025-10 | -9.50 | -4.50 |
| 2025-11 | 7.51 | 4.50 |
| 2025-12 | 3.50 | 4.00 |
| 2026-01 | 1.50 | 3.99 |
| 2026-02 | 2.50 | 4.00 |
| 2026-03 | 0.99 | 0.99 |

## Full Run RejectReason Counts
| RejectReason | C_SHORT_MODE | J_SHORT_MODE |
| --- | --- | --- |
| break_candle_strength_filter_failed | 0 | 231 |
| consecutive_loss_blocked | 18 | 4 |
| direction_filter_failed | 4141 | 4141 |
| entry_open_count_filter_failed | 0 | 183 |
| fibo_filter_failed | 184 | 184 |
| max_positions_blocked | 65 | 0 |
| pattern_adx_bucket_filter_failed | 1032 | 1032 |
| rr_too_low | 1 | 1 |
| spread_too_wide | 46 | 21 |
| trend_alignment_filter_failed | 2274 | 2274 |

## EnableTrading=true Smoke
- J Short / 2026Q1 tester smoke completed with `30` closed simulated live trades, expectancy `0.0586R`, PF `1.1012`.
- This smoke test checks the order path does not break; it is not a virtual expectancy comparison because fills and money-based trade handling differ from virtual logging.

## Readout
- `SelectedStrategyMode=STRATEGY_01B_C_SHORT` exactly reproduced the prior C ShortOnly full-window metrics: `505` trades, `+0.1484R`, PF `1.2744`.
- `SelectedStrategyMode=STRATEGY_01B_J_SHORT` exactly reproduced the prior J ShortOnly full-window metrics: `340` trades, `+0.1467R`, PF `1.2711`.
- The frozen StrategyMode implementation removes the gap between diagnostic filtering and the executable strategy guard.
- No demo/live promotion is made here. The code is ready for a forward-demo preparation pass with conservative risk settings.

## Artifacts
| Artifact | Path |
| --- | --- |
| Run manifest | [manifest.csv](./manifest.csv) |
| Run metrics | [run_metrics.csv](./run_metrics.csv) |
| Comparison to direction-filter run | [comparison_to_direction_filter.csv](./comparison_to_direction_filter.csv) |
| Promotion check | [promotion_check.csv](./promotion_check.csv) |
| Monthly ProfitR | [monthly_profit_r_full_runs.csv](./monthly_profit_r_full_runs.csv) |
| Reject counts | [reject_counts_by_run.csv](./reject_counts_by_run.csv) |
| Raw summaries | [raw_summaries/](./raw_summaries/) |
