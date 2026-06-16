# Nested Context Router RR 1.2 Annual Check

Annual check compares the original instant all-candidates RR 1.2 branch against `ContextQualityRouterV2` and `ContextQualityRouterV3`.

`ContextQualityRouterV2` adds a minimum weak-breakout body check (`breakout_body_atr >= 0.20`) on top of the first context router. `ContextQualityRouterV3` keeps v2 and adds a Friday 21:00+ server-time new-entry guard for Nested setups.

| period | scenario | trades | PF | avg_R | net | maxDD% | FX net | XAUUSD net | long net | short net |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2024 | instant_all_r12 | 78 | 0.886 | -0.071 | -253.96 | 7.43 | -110.47 | -143.49 | -30.84 | -223.12 |
| 2024 | context_router_v2_all_r12 | 28 | 0.908 | -0.059 | -74.12 | 4.02 | -88.99 | 14.87 | 57.81 | -131.93 |
| 2024 | context_router_v3_all_r12 | 28 | 0.908 | -0.059 | -74.12 | 4.02 | -88.99 | 14.87 | 57.81 | -131.93 |
| 2025 | instant_all_r12 | 92 | 1.022 | 0.041 | 53.45 | 5.64 | -107.76 | 161.21 | -178.68 | 232.13 |
| 2025 | context_router_v2_all_r12 | 36 | 0.777 | -0.116 | -253.03 | 4.23 | 3.61 | -256.64 | -285.81 | 32.78 |
| 2025 | context_router_v3_all_r12 | 35 | 0.952 | -0.003 | -45.03 | 2.28 | 1.26 | -46.29 | -285.81 | 240.78 |
| 2026YTD | instant_all_r12 | 36 | 0.922 | -0.03 | -75.36 | 5.33 | -55.02 | -20.34 | -269.07 | 193.71 |
| 2026YTD | context_router_v2_all_r12 | 12 | 1.129 | 0.088 | 34.76 | 1.82 | 73.21 | -38.45 | 74.12 | -39.36 |
| 2026YTD | context_router_v3_all_r12 | 11 | 0.938 | -0.013 | -16.8 | 1.82 | 73.21 | -90.01 | 74.12 | -90.92 |

## Aggregate

| scenario | trades | PF | avg_R | net | maxDD% | FX net | XAUUSD net |
|---|---:|---:|---:|---:|---:|---:|---:|
| context_router_v2_all_r12 | 76 | 0.867 | -0.063 | -292.39 | 7.54 | -12.17 | -280.22 |
| context_router_v3_all_r12 | 74 | 0.932 | -0.026 | -135.95 | 5.81 | -14.52 | -121.43 |
| instant_all_r12 | 206 | 0.951 | -0.014 | -275.87 | 12.16 | -273.25 | -2.62 |

## Judgement

- This is a robustness check, not a promotion test.
- V2 passed the short-period test, but failed annual validation: 2024 remained negative, 2025 deteriorated badly, and 2026YTD improved.
- V3 removed the 2025 weekend gap outlier and reduced drawdown, but still did not create positive expectancy. Three-period aggregate was `PF 0.932`, `avg_R -0.026`, `net -135.95`.
- The instant RR 1.2 baseline still had the best aggregate PF/avg_R among the annual checks (`PF 0.951`, `avg_R -0.014`), even though its drawdown was worse.
- Conclusion: Context filtering and weekend risk control are useful diagnostics/risk controls, but the current Nested N-Wave entry definition does not yet have robust positive expectancy.
- Further threshold tuning is not justified from these results. The next real improvement would need a better setup definition, especially around H4/H1 context and XAUUSD long failure regimes, not another M15 candle gate.
