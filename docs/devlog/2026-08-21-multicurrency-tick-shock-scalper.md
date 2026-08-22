# Multi-currency tick-shock research redesign (historical)

This entry records the v4 research redesign that replaced the invalid original comparison. It aligned baseline and signal measures, added noise-floor handling, retained all events, fixed MFE/MAE anchors, unified continuation/reversal scenario evaluation, and split research from order reachability.

The v4 result still had execution-model defects and therefore remained `EDGE_UNDETERMINED`. It has been superseded by [the 2026-08-22 execution revision](2026-08-22-tick-shock-execution-revision.md).

Historical evidence: [v4 report](../../reports/backtest/runs/20260821_tickshock_research_v4_final/summary.md).
