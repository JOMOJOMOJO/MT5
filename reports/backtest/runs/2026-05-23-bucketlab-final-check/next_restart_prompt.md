# Next Restart Prompt

Use this prompt when restarting the ExpectedValue LongOnly BucketLab research.

```text
ExpectedValue_LongOnly_BucketLab research was archived on 2026-05-23.

Please resume from the research asset state, not from production promotion.

Protected files:
- Do not modify mql/Experts/ExpectedValue_NWave_Scalper.mq5.
- Do not modify mql/Experts/ExpectedValue_LongOnly_RelativeScalper.mq5.
- Do not mutate reports/backtest/candidates/expected-value-long-bucketlab-candidate-v1/.

First read:
- reports/backtest/runs/2026-05-23-bucketlab-final-check/final_research_decision.md
- reports/backtest/runs/2026-05-23-bucketlab-final-check/final_check_results.md
- reports/backtest/runs/2026-05-23-bucketlab-final-check/assets_index.md
- reports/backtest/runs/2026-05-21-bucketlab-v2-5-oos-nearmiss-diagnostic/summary.md
- docs/devlog/2026-05-19-expected-value-long-bucketlab.md

Current conclusion:
- Do not promote the current long-only BucketLab to demo or live.
- v2.5 is good in 2025 but almost stops trading in 2026 Jan-Apr OOS.
- OOS must not be used for threshold tuning.
- The current expansion/shallow M1 family is too regime-specific.

Best restart direction:
- Start a new market-state family from bar-data/statistical discovery.
- Prefer a longer-hold M5/M15 continuation thesis over more M1 scalper threshold tweaks.
- Keep M1 only as execution if useful.
- Use 2025 or another development slice for hypothesis formation.
- Lock a candidate before any OOS check.

Useful retained infrastructure:
- risk sizing
- fixed lot for small capital
- daily/weekly/DD/loss-streak stops
- no averaging / no martingale
- total open risk checks
- second-entry quality gate
- bucket logging
- candidate score logging
- bucket near-miss diagnostics
- monthly/bucket/exit analysis CSVs

Do not:
- loosen Spread/ATR only to increase frequency
- add 3-position stacking
- tune to 2026 Jan-Apr OOS
- call any preset in the final-check folder a production candidate

Task:
Design one new research family, define its market-state hypothesis, implement it as a separate disabled-by-default bucket or separate EA, run 2025-only validation first, and write a concise devlog linking code to evidence.
```

