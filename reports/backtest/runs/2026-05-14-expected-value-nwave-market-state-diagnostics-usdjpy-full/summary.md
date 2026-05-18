# Market-State Diagnostics - USDJPY Full Window

- Generated: 2026-05-14
- EA: `ExpectedValue_NWave_Scalper` / Strategy: `Strategy_01_NWave_ExpectedValue`
- Run: `market-tags-usdjpy-full-2024-2026q1` / Magic `2026051450`
- Test: `USDJPY M5`, `2024.01.01` to `2026.03.30`, `EnableTrading=false`, `H4/M15/M5`, `MaxManagedPositions=2`, `TP=1.5R`, `MinRR=1.2`, `FILTER_ALL`, conservative same-bar exit enabled.
- Scope: diagnostic tagging only. No entry rule, session filter, direction filter, exit management, or optimization change was added.

## Main Result
| Closed | Win% | AvgWinR | AvgLossR | ExpectancyR | PF | MaxLosses | MaxDD_R |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2848 | 38.52 | 1.5000 | -1.0000 | -0.0371 | 0.9397 | 12 | 141.0338 |

## Year Split From Full Diagnostic CSV
This is a calendar-year split of the completed full-window diagnostic CSV, not separate MT5 reruns.
| Year | Closed | Win% | ExpectancyR | PF | MaxDD_R | MaxLosses |
| --- | --- | --- | --- | --- | --- | --- |
| 2024 | 1205 | 39.34 | -0.0166 | 0.9726 | 43.0142 | 11 |
| 2025 | 1327 | 37.08 | -0.0731 | 0.8838 | 107.0638 | 12 |
| 2026 | 316 | 41.46 | 0.0364 | 1.0622 | 13.0013 | 9 |

## HTF Trend State ExpectancyR
| HTFTrendState | Trades | Win% | ExpectancyR | PF |
| --- | --- | --- | --- | --- |
| bearish | 747 | 37.88 | -0.0529 | 0.9149 |
| bullish | 1206 | 38.72 | -0.0319 | 0.9479 |
| flat | 72 | 48.61 | 0.2151 | 1.4186 |
| mixed | 823 | 37.91 | -0.0522 | 0.9159 |

## ADX Bucket ExpectancyR
EntryTF bucket:
| EntryADXBucket | Trades | Win% | ExpectancyR | PF |
| --- | --- | --- | --- | --- |
| high | 958 | 39.87 | -0.0032 | 0.9947 |
| low | 610 | 38.69 | -0.0328 | 0.9465 |
| middle | 1280 | 37.42 | -0.0644 | 0.8970 |

PatternTF bucket:
| PatternADXBucket | Trades | Win% | ExpectancyR | PF |
| --- | --- | --- | --- | --- |
| high | 1071 | 36.69 | -0.0826 | 0.8695 |
| low | 601 | 36.61 | -0.0849 | 0.8662 |
| middle | 1176 | 41.16 | 0.0289 | 1.0491 |

## ATR Bucket ExpectancyR
EntryTF ATR percentile bucket:
| EntryATRBucket | Trades | Win% | ExpectancyR | PF |
| --- | --- | --- | --- | --- |
| high_vol | 1132 | 38.60 | -0.0349 | 0.9431 |
| low_vol | 649 | 38.06 | -0.0485 | 0.9216 |
| normal_vol | 1067 | 38.71 | -0.0323 | 0.9472 |

PatternTF ATR percentile bucket:
| PatternATRBucket | Trades | Win% | ExpectancyR | PF |
| --- | --- | --- | --- | --- |
| high_vol | 755 | 39.34 | -0.0166 | 0.9726 |
| low_vol | 952 | 38.76 | -0.0310 | 0.9493 |
| normal_vol | 1141 | 37.77 | -0.0556 | 0.9106 |

## Trend Alignment ExpectancyR
| TrendAlignmentTag | Trades | Win% | ExpectancyR | PF |
| --- | --- | --- | --- | --- |
| CounterTrend | 1000 | 40.40 | 0.0099 | 1.0166 |
| MixedTrend | 895 | 38.77 | -0.0307 | 0.9498 |
| TrendFollow | 953 | 36.31 | -0.0923 | 0.8551 |

## Session x Direction x HTF Trend State
| Session | Direction | HTFTrendState | Trades | Win% | ExpectancyR | PF |
| --- | --- | --- | --- | --- | --- | --- |
| asia | LONG | bearish | 138 | 44.93 | 0.1232 | 1.2237 |
| asia | LONG | bullish | 237 | 33.76 | -0.1559 | 0.7646 |
| asia | LONG | flat | 12 | 58.33 | 0.4582 | 2.0998 |
| asia | LONG | mixed | 174 | 43.10 | 0.0777 | 1.1366 |
| asia | SHORT | bearish | 135 | 43.70 | 0.0925 | 1.1643 |
| asia | SHORT | bullish | 225 | 40.89 | 0.0219 | 1.0371 |
| asia | SHORT | flat | 5 | 20.00 | -0.5010 | 0.3737 |
| asia | SHORT | mixed | 155 | 38.06 | -0.0487 | 0.9214 |
| late_us | LONG | bearish | 18 | 33.33 | -0.1666 | 0.7501 |
| late_us | LONG | bullish | 27 | 22.22 | -0.4442 | 0.4289 |
| late_us | LONG | mixed | 17 | 23.53 | -0.4117 | 0.4616 |
| late_us | SHORT | bearish | 9 | 33.33 | -0.1668 | 0.7499 |
| late_us | SHORT | bullish | 25 | 48.00 | 0.1985 | 1.3817 |
| late_us | SHORT | mixed | 16 | 50.00 | 0.2501 | 1.5001 |
| london | LONG | bearish | 108 | 34.26 | -0.1434 | 0.7819 |
| london | LONG | bullish | 148 | 37.16 | -0.0706 | 0.8876 |
| london | LONG | flat | 15 | 53.33 | 0.3333 | 1.7142 |
| london | LONG | mixed | 103 | 40.78 | 0.0198 | 1.0334 |
| london | SHORT | bearish | 88 | 37.50 | -0.0626 | 0.8998 |
| london | SHORT | bullish | 171 | 42.11 | 0.0527 | 1.0910 |
| london | SHORT | flat | 12 | 58.33 | 0.4578 | 2.0987 |
| london | SHORT | mixed | 120 | 25.83 | -0.3542 | 0.5224 |
| new_york | LONG | bearish | 127 | 36.22 | -0.0943 | 0.8521 |
| new_york | LONG | bullish | 185 | 39.46 | -0.0135 | 0.9777 |
| new_york | LONG | flat | 9 | 44.44 | 0.1114 | 1.2006 |
| new_york | LONG | mixed | 119 | 40.34 | 0.0085 | 1.0143 |
| new_york | SHORT | bearish | 124 | 29.84 | -0.2541 | 0.6378 |
| new_york | SHORT | bullish | 188 | 40.96 | 0.0237 | 1.0402 |
| new_york | SHORT | flat | 19 | 42.11 | 0.0525 | 1.0907 |
| new_york | SHORT | mixed | 119 | 37.82 | -0.0548 | 0.9119 |

## Break Candle Strength ExpectancyR
| BreakCandleStrengthBucket | Trades | Win% | ExpectancyR | PF |
| --- | --- | --- | --- | --- |
| high | 2188 | 39.67 | -0.0083 | 0.9863 |
| low | 117 | 35.90 | -0.1027 | 0.8397 |
| middle | 543 | 34.44 | -0.1390 | 0.7881 |

## Open Position Context ExpectancyR
SameDirectionOpenCount:
| SameDirectionOpenCount | Trades | Win% | ExpectancyR | PF |
| --- | --- | --- | --- | --- |
| 0 | 2009 | 39.07 | -0.0232 | 0.9619 |
| 1 | 839 | 37.19 | -0.0702 | 0.8882 |

OppositeDirectionOpenCount:
| OppositeDirectionOpenCount | Trades | Win% | ExpectancyR | PF |
| --- | --- | --- | --- | --- |
| 0 | 2137 | 38.37 | -0.0407 | 0.9339 |
| 1 | 711 | 38.96 | -0.0261 | 0.9573 |

EntryOpenCount:
| EntryOpenCount | Trades | Win% | ExpectancyR | PF |
| --- | --- | --- | --- | --- |
| 0 | 1298 | 39.14 | -0.0216 | 0.9645 |
| 1 | 1550 | 38.00 | -0.0500 | 0.9194 |

## Exit Diagnostics
| Metric | Count/Value |
| --- | --- |
| MFE_R >= 0.5 reached | 1815 |
| MFE_R >= 1.0 reached | 1356 |
| MFE_R >= 0.5 then SL/loss | 718 |
| MFE_R >= 1.0 then SL/loss | 259 |
| Loss trades with MFE_R >= 0.5 | 721 |
| Loss trades with MFE_R >= 1.0 | 260 |
| Winning-trade avg MAE_R | -0.5191 |
| HoldingBars avg | 53.94 |
| HoldingBars median | 21.00 |
| HoldingBars max | 3645.00 |

## Reject Counts
| RejectReason | Count |
| --- | --- |
| consecutive_loss_blocked | 1320 |
| daily_loss_blocked | 316 |
| fibo_filter_failed | 184 |
| max_positions_blocked | 2620 |
| rr_too_low | 1 |
| spread_too_wide | 329 |

## Added Diagnostic Columns
`ContextEMAShort`, `ContextEMALong`, `ContextEMAShortAboveLong`, `ContextEMAShortSlopeATR`, `ContextEMALongSlopeATR`, `ContextPriceVsEMAShort`, `ContextPriceVsEMALong`, `HTFTrendState`, `PatternADX`, `EntryADX`, `PatternADXBucket`, `EntryADXBucket`, `PatternDIDirection`, `EntryDIDirection`, `PatternATR`, `EntryATR`, `PatternATRPercentile`, `EntryATRPercentile`, `PatternATRBucket`, `EntryATRBucket`, `SLDistanceATR`, `TPDistanceATR`, `DoubleTopBottomHeightATR`, `NecklineDistanceATR`, `RightPeakOrBottomDepthATR`, `LeftRightSymmetryRatio`, `BreakCandleBodyATR`, `BreakCandleClosePosition`, `BreakCandleDirectionStrength`, `BreakCandleStrengthBucket`, `ContextDirectionAligned`, `TrendAlignmentTag`, `EntryOpenCount`, `SameDirectionOpenCount`, `OppositeDirectionOpenCount`, `BarsSinceLastEntry`, `ApproximateDuplicateSetup`, `MFEReached05`, `MFEReached10`, `MFE05ThenSL`, `MFE10ThenSL`

## Artifacts
| Artifact | Path |
| --- | --- |
| Diagnostics CSV | [diagnostics.csv](./diagnostics.csv) |
| EA summary CSV | [summary.csv](./summary.csv) |
| Tag expectancy CSVs | `tag_*.csv` in this directory |
| Session x Direction x HTF CSV | [session_direction_htf_trend.csv](./session_direction_htf_trend.csv) |
| MT5 HTML | [ExpectedValue_NWave_Scalper-market-tags-usdjpy-full-2024-2026q1.htm](../../imported/ExpectedValue_NWave_Scalper-market-tags-usdjpy-full-2024-2026q1.htm) |

## Readout
Positive buckets with at least 100 trades:
| Family | Bucket | Trades | ExpectancyR |
| --- | --- | --- | --- |
| TrendAlignment | CounterTrend | 1000 | 0.0099 |

This evidence is for diagnosis only; it does not promote a filter or parameter change by itself.
