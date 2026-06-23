# FX Elliott Wave Roadmap Diagnostics

## Implementation
- Elliott Wave was implemented as a roadmap label system, not as strict wave counting.
- H1/H4 pivots use confirmed closed bars only. With InpSwingDepth=3, a pivot is usable only after 3 right-side closed bars. ZigZag repaint values are not used.
- CSV includes pivot_confirmation_delay_bars, entry_delay_from_pivot, pivot_time, and pivot_confirmed_time. No future high/low is used at entry decision time.
- Symbols: USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD. No XAUUSD, symbol exclusion, direction-only gate, or Friday stop was used.

## 2025 Shallow Gate
- wave3_start_pullback_only: trades=446, PF=0.71, avg_R=-0.1283, net=-1,277.96, DD_stop=true, passed=False, failed=pf_lt_1.05;avg_r_le_0;net_le_0;dd_stopped
- wave4_continuation_only: trades=356, PF=0.66, avg_R=-0.1646, net=-1,317.17, DD_stop=true, passed=False, failed=pf_lt_1.05;avg_r_le_0;net_le_0;dd_stopped
- abc_completion_reentry_only: trades=601, PF=0.76, avg_R=-0.0963, net=-1,386.13, DD_stop=true, passed=False, failed=pf_lt_1.05;avg_r_le_0;net_le_0;dd_stopped
- combined_roadmap_triggers: trades=551, PF=0.72, avg_R=-0.1125, net=-1,412.68, DD_stop=true, passed=False, failed=pf_lt_1.05;avg_r_le_0;net_le_0;dd_stopped;direction_balance_failed;currency_concentration_or_negative_net

## Diagnostics
- Most promising setup by avg_R in 2025 diagnostics: combined_roadmap_triggers / abc_completion_reentry, trades=123, avg_R=-0.0161, PF_from_trades=0.93.
- wave3_break_confirmed=true avg_R=-0.0215; false avg_R=-0.1608. If false is materially worse, wave3_start is too early.
- wave4_continuation showed chase risk rather than continuation edge: standalone avg_R=-0.1646, combined wave4 avg_R=-0.2119.
- abc_completion was the least bad combined component but still not a deployment edge: combined avg_R=-0.0161 on 123 trades; standalone avg_R=-0.0963 on 601 trades.
- wave5 exhaustion chase avoidance diagnostics recorded: 10160 signal rows in combined_roadmap_triggers.
- Fib confluence best true bucket avg_R=-0.0192; best false bucket avg_R=-0.0117. Use breakdown CSV before treating fib as a hard gate.
- Divergence-present best bucket avg_R=-0.1260; divergence-none best bucket avg_R=0.0594. Divergence is diagnostic, not optimized as a hard gate.
- M15 confirmation type performance: best bucket abc_completion_reentry_only/micro_bos avg_R=0.0045; weakest bucket wave4_continuation_only/micro_bos avg_R=-0.2207. Full table: m15_confirmation_breakdown.csv.
- Largest failure bucket: wave3_start_pullback_only/wave3_unconfirmed_too_early, trades=208, net=-3,870.11, avg_R=-0.8210.
- Failure hot spots are saved in failure_type_breakdown.csv, plus setup/fib/divergence/room/wave3 confirmation breakdowns.

## Promotion
- No deployment candidate is promoted to 3-year/OOS from this run. The combined candidate failed 2025 shallow gate conditions.
- Because 2025 shallow gate failed for deployment, no symbol exclusion, direction-only repair, Friday stop, or narrow RSI/MACD/Fib retuning was applied.
- Deployable candidate: none from this cycle.
