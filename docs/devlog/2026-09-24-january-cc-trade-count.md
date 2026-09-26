# 2026-09-24 January trade-count diagnosis

Read-only inspection of latest run in Agent-127.0.0.1-3000/logs/20260924.log (22:09:00–22:11:14). EA: USDJPY_M1_M5_3WaveIn3Wave_Long_CC, January 2025.

Inputs confirmed: InpHigherUseClosePivot=true; InpSkipLowerHL=false; InpGateAtM5Wave1High=true; RR=1.2; STOP_M1_WAVE2_LOW; cooldown=15.

9 TW_SIGNAL events: 8 MARKET_BUY_WITH_SLTP sent=true, 1 ENTRY_AT_M5_WAVE1_HIGH sent=false. The additional high-price gate explains only one rejection in this run. Most scarcity occurs before READY. Close-pivot input differs from the frozen research baseline; causal contribution to reduced candidate count has not been isolated.

The [context research](../../reports/qa/three_wave/context_research/summary.md) had January primary CHoCH 53, HL 32, READY 23; these are frozen shadow-research counts, not guaranteed orders for this CC preset. EMA was added to the non-CC EA in the [display task](2026-09-24-three-wave-ema-display.md), not this CC binary. No settings or strategy files changed during this diagnosis. No seed: local configuration diagnosis only.
