# FX Fractal Dow Elliott Session Diagnostics

## Implementation Notes
- This EA is ExpectedValue_MultiCurrency_FXFractalDowElliottSessionTrader with strategy tag RESEARCH_STRATEGY_FX_FRACTAL_DOW_ELLIOTT_SESSION.
- Elliott Wave is implemented as a roadmap label, not strict wave counting. The EA records wave_stage, setup_type, fib_zone, divergence_type, wave3_break_confirmed, pivot timing, Dow regimes, session labels, and volatility ranks.
- H1/H4 pivots use confirmed closed bars only. With InpSwingDepth=3, pivots are usable only after the right-side 3 closed bars. ZigZag repaint buffers are not used. Summary policy: confirmed_pivots_only_no_repaint_zigzag.
- Symbols tested: USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD. No XAUUSD, symbol exclusion, direction-only gate, Friday stop, or narrow threshold repair was used.
- Session labels are derived from server time using broker_utc_offset_used=2. Overlap is labeled before London/New York for UTC 13-16.

## 2025 Shallow BT Comparison
- baseline_all_sessions: trades=339, PF=0.65, avg_R=-0.1980, net=-1,502.75, DD_stop=true, primary_gate=True, passed=False, failed=pf_lt_1.05;avg_r_le_0;net_le_0;dd_stopped;direction_balance_failed;symbol_concentration_or_negative_net
- session_volatility_only_filter: trades=268, PF=0.62, avg_R=-0.2141, net=-1,309.22, DD_stop=true, primary_gate=True, passed=False, failed=pf_lt_1.05;avg_r_le_0;net_le_0;dd_stopped;direction_balance_failed;symbol_concentration_or_negative_net
- london_only_reference: trades=271, PF=0.57, avg_R=-0.2466, net=-1,480.49, DD_stop=true, primary_gate=False, passed=False, failed=reference_only_not_primary_gate;pf_lt_1.05;avg_r_le_0;net_le_0;dd_stopped;direction_balance_failed;symbol_concentration_or_negative_net;session_concentration
- newyork_only_reference: trades=314, PF=0.60, avg_R=-0.1950, net=-1,425.97, DD_stop=true, primary_gate=False, passed=False, failed=reference_only_not_primary_gate;pf_lt_1.05;avg_r_le_0;net_le_0;dd_stopped;direction_balance_failed;symbol_concentration_or_negative_net;session_concentration
- tokyo_only_reference: trades=337, PF=0.68, avg_R=-0.1735, net=-1,330.95, DD_stop=true, primary_gate=False, passed=False, failed=reference_only_not_primary_gate;pf_lt_1.05;avg_r_le_0;net_le_0;dd_stopped;direction_balance_failed;symbol_concentration_or_negative_net;session_concentration
- london_newyork_overlap_reference: trades=226, PF=0.61, avg_R=-0.1892, net=-1,019.79, DD_stop=false, primary_gate=False, passed=False, failed=reference_only_not_primary_gate;pf_lt_1.05;avg_r_le_0;net_le_0;direction_balance_failed;symbol_concentration_or_negative_net;session_concentration
- symbol_best_session: trades=268, PF=0.62, avg_R=-0.2141, net=-1,309.22, DD_stop=true, primary_gate=True, passed=False, failed=pf_lt_1.05;avg_r_le_0;net_le_0;dd_stopped;direction_balance_failed;symbol_concentration_or_negative_net
- symbol_best_session_with_dow_alignment: trades=288, PF=0.59, avg_R=-0.2329, net=-1,485.20, DD_stop=true, primary_gate=True, passed=False, failed=pf_lt_1.05;avg_r_le_0;net_le_0;dd_stopped;direction_balance_failed;symbol_concentration_or_negative_net
- symbol_best_session_with_wave3_confirmed: trades=147, PF=0.89, avg_R=-0.0428, net=-165.82, DD_stop=false, primary_gate=True, passed=False, failed=trades_lt_200;pf_lt_1.05;avg_r_le_0;net_le_0;direction_balance_failed;symbol_concentration_or_negative_net

## Session Findings
- Best scenario by net: symbol_best_session_with_wave3_confirmed, net=-165.82, PF=0.89, avg_R=-0.0428, DD_stop=false.
- Best scenario by avg_R: symbol_best_session_with_wave3_confirmed, trades=147, avg_R=-0.0428, PF=0.89.
- Best primary-gate scenario by avg_R: symbol_best_session_with_wave3_confirmed, trades=147, avg_R=-0.0428, PF=0.89, failed=trades_lt_200;pf_lt_1.05;avg_r_le_0;net_le_0;direction_balance_failed;symbol_concentration_or_negative_net.
- Top symbol/session audit buckets by avg_R_if_traded:
  - london_newyork_overlap_reference/USDJPY/tokyo: avg_R_if_traded=0.0000, PF_if_traded=0.00, net_if_traded=0.00, avg_m15_range_atr=1.085, followthrough=0.864
  - symbol_best_session/AUDJPY/london: avg_R_if_traded=0.0000, PF_if_traded=0.00, net_if_traded=0.00, avg_m15_range_atr=1.001, followthrough=0.868
  - london_newyork_overlap_reference/USDJPY/new_york: avg_R_if_traded=0.0000, PF_if_traded=0.00, net_if_traded=0.00, avg_m15_range_atr=0.801, followthrough=0.771
  - london_newyork_overlap_reference/USDJPY/other: avg_R_if_traded=0.0000, PF_if_traded=0.00, net_if_traded=0.00, avg_m15_range_atr=1.048, followthrough=0.793
  - symbol_best_session/AUDJPY/other: avg_R_if_traded=0.0000, PF_if_traded=0.00, net_if_traded=0.00, avg_m15_range_atr=1.168, followthrough=0.826
  - symbol_best_session/AUDJPY/tokyo: avg_R_if_traded=0.0000, PF_if_traded=0.00, net_if_traded=0.00, avg_m15_range_atr=1.028, followthrough=0.849
  - symbol_best_session/AUDJPY/london_newyork_overlap: avg_R_if_traded=0.0000, PF_if_traded=0.00, net_if_traded=0.00, avg_m15_range_atr=1.272, followthrough=0.907
  - symbol_best_session/AUDJPY/new_york: avg_R_if_traded=0.0000, PF_if_traded=0.00, net_if_traded=0.00, avg_m15_range_atr=0.823, followthrough=0.784
  - london_newyork_overlap_reference/GBPUSD/london_newyork_overlap: avg_R_if_traded=0.0000, PF_if_traded=0.00, net_if_traded=0.00, avg_m15_range_atr=1.201, followthrough=0.905
  - london_newyork_overlap_reference/GBPUSD/new_york: avg_R_if_traded=0.0000, PF_if_traded=0.00, net_if_traded=0.00, avg_m15_range_atr=0.793, followthrough=0.789

## Diagnostic Findings
- Best setup/session bucket: symbol_best_session/wave4_continuation/new_york, trades=1, avg_R=1.4010, PF_from_trades=∞.
- Best Dow regime bucket: tokyo_only_reference, H4=transition_down, H1=range, trades=1, avg_R=1.4080.
- Largest losing failure bucket: baseline_all_sessions/wave3_unconfirmed_too_early, trades=157, net=-3,289.33, avg_R=-0.9306.
- wave3_break_confirmed comparison:
  - baseline_all_sessions, wave3_break_confirmed=false: trades=250, avg_R=-0.2925, PF_from_trades=0.54
  - baseline_all_sessions, wave3_break_confirmed=true: trades=89, avg_R=0.0673, PF_from_trades=1.19
  - london_newyork_overlap_reference, wave3_break_confirmed=false: trades=166, avg_R=-0.1990, PF_from_trades=0.61
  - london_newyork_overlap_reference, wave3_break_confirmed=true: trades=60, avg_R=-0.1620, PF_from_trades=0.59
  - london_only_reference, wave3_break_confirmed=false: trades=207, avg_R=-0.2880, PF_from_trades=0.54
  - london_only_reference, wave3_break_confirmed=true: trades=64, avg_R=-0.1125, PF_from_trades=0.74
  - newyork_only_reference, wave3_break_confirmed=false: trades=218, avg_R=-0.1603, PF_from_trades=0.65
  - newyork_only_reference, wave3_break_confirmed=true: trades=96, avg_R=-0.2737, PF_from_trades=0.47
  - session_volatility_only_filter, wave3_break_confirmed=false: trades=201, avg_R=-0.2952, PF_from_trades=0.52
  - session_volatility_only_filter, wave3_break_confirmed=true: trades=67, avg_R=0.0292, PF_from_trades=1.06
  - symbol_best_session, wave3_break_confirmed=false: trades=201, avg_R=-0.2952, PF_from_trades=0.52
  - symbol_best_session, wave3_break_confirmed=true: trades=67, avg_R=0.0292, PF_from_trades=1.06
  - symbol_best_session_with_dow_alignment, wave3_break_confirmed=false: trades=202, avg_R=-0.3124, PF_from_trades=0.51
  - symbol_best_session_with_dow_alignment, wave3_break_confirmed=true: trades=86, avg_R=-0.0461, PF_from_trades=0.89
  - symbol_best_session_with_wave3_confirmed, wave3_break_confirmed=false: trades=12, avg_R=-0.2632, PF_from_trades=0.46
  - symbol_best_session_with_wave3_confirmed, wave3_break_confirmed=true: trades=135, avg_R=-0.0232, PF_from_trades=0.93
  - tokyo_only_reference, wave3_break_confirmed=false: trades=254, avg_R=-0.1929, PF_from_trades=0.66
  - tokyo_only_reference, wave3_break_confirmed=true: trades=83, avg_R=-0.1142, PF_from_trades=0.75
- M15 confirmation, wave_stage, setup_type, fib_zone, divergence_type, failure_type, Dow regime, session, symbol-session, setup-session, and direction-session details are in the generated CSVs.

## Promotion Decision
- No primary scenario passed the 2025 shallow gate, so no 3-year fixed BT or latest 12-month OOS was run.
- Deployable candidate from this cycle: none unless a later manual review overrides the no-promotion rule, which is not recommended from this dataset.
