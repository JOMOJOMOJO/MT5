# Frozen HL entry comparison plan

2026-09-25. Compare READY / first valid confirmed HL immediate / first confirmed HL retest. Research-only EA; production, Shared and order logic unchanged.

Fixed: USDJPY M1/M5, Jan1-Apr1 2025 exclusive, Model4, EMA ordered+rising ON, RR1, risk Equity1%, pivots2/2, cooldown15min, common SL = reversal low -10points in all three modes. The different SL from prior READY studies requires a fresh READY reference. No thresholds optimized.

HL immediate: first available quote after a newly confirmed first valid HL, no renewed breakout required. Retest: freeze that first HL; require Bid>=HL and Ask<=HL+0.25*(HL-commonSL). If already inside on confirmation, enter then. Otherwise monitor ticks. HL/origin break, parent expiry/break or expired READY ends monitoring. Later HL revisions do not move the frozen level. First decision is consumed even if EMA/exposure/cooldown rejects; no chasing. At most one decision per parent in added modes.

Run a short smoke first, then the three full Q1 modes. Validate exact closed confirmation times, actual Ask proximity, unchanged MakePlan/Place/Manage functions, SL/risk/cooldown/ownership and report reconciliation. Report monthly frequency, net R, net PnL, PF, native equity DD and real-tick quality. Q1 is already observed data, not OOS. No live promotion based on Q1.
