# USDJPY Follow-Through Long Cycle 1 Reject

## Intent

- Open a fresh `USDJPY` long-only family after the `golden_method` and `zone_escape` kills.
- Keep the doctrine aligned to:
  - `EMA13 / EMA100`,
  - Dow-style swing trend,
  - follow-through phase entries,
  - V-shape pullback preference,
  - `50 pip` same-zone avoidance,
  - roughly `1 trade/day` as a practical operating target.

## What Was Built

- Long-only event study:
  - [usdjpy_golden_s1_long_event_study.py](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/plugins/mt5-company/scripts/usdjpy_golden_s1_long_event_study.py)
  - [run-usdjpy-golden-s1-long-event-study.ps1](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/scripts/run-usdjpy-golden-s1-long-event-study.ps1)
- Fresh long-only EA family:
  - [usdjpy_20260402_followthrough_long.mq5](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/mql/Experts/usdjpy_20260402_followthrough_long.mq5)
- Baseline preset and train/OOS configs:
  - [usdjpy_20260402_followthrough_long-baseline.set](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/presets/usdjpy_20260402_followthrough_long-baseline.set)
  - [usdjpy_20260402_followthrough_long-train-9m.ini](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/usdjpy_20260402_followthrough_long-train-9m.ini)
  - [usdjpy_20260402_followthrough_long-oos-3m.ini](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/usdjpy_20260402_followthrough_long-oos-3m.ini)

## Study Result

- Default `10 pip / 1.2R / 96 bars` style settings produced no candidate with positive train and positive OOS expectancy at the same time.
- A looser `15 pip stop / 0.8R / 72 bars` study did produce positive-both candidates.
- Best reusable cluster:
  - `london_ny`
  - `max_countertrend_bodies <= 1`
  - `max_pullback_ratio <= 0.45`
  - `min_impulse >= 14 pips`
  - `min_rejection_close_location >= 0.60`
- However, the resulting trade frequency was still very low:
  - roughly `0.07 - 0.12 trades/day`,
  - far below the business target of `>= 1 trade/day`.

Study outputs:
- [summary.md](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/research/2026-04-02-120419-usdjpy-m5-golden-s1-long-event-study/summary.md)
- [sl15-r08-h72 candidates](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/research/usdjpy-s1-long-sl15-r08-h72/candidates.csv)

## Actual MT5 Result

- First strict EA version was too far from the study and traded almost not at all.
- The fresh family was then aligned closer to the study:
  - looser rejection-body requirement,
  - looser pullback distance,
  - looser transition distance,
  - spread limit raised to `2.3`,
  - explicit `max hold bars = 72` added.

Actual MT5 results after alignment:
- Train `2025-04-01 -> 2025-12-31`:
  - `net +259.31`
  - `PF 1.65`
  - `6 trades`
  - `DD 2.04%`
  - [train run](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/runs/usdjpy-20260402-followthrough-long/usdjpy/m5/2026-04-02-123948-774240-usdjpy-20260402-followthrough-lo.json)
- OOS `2026-01-01 -> 2026-04-01`:
  - `net -430.24`
  - `PF 0.27`
  - `4 trades`
  - `DD 4.30%`
  - [oos run](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/runs/usdjpy-20260402-followthrough-long/usdjpy/m5/2026-04-02-124002-623823-usdjpy-20260402-followthrough-lo.json)

## Verdict

- `Reject` for promotion.
- Reasons:
  - trade count is still far too low,
  - the positive train did not survive the latest `3 month` OOS,
  - the family is not close enough to the repo `live-ready` definition.

Reference:
- [live-ready-definition.md](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/knowledge/patterns/2026-04-01-live-ready-definition.md)

## Reusable Lessons

- The requested `Golden Method` doctrine does contain a real long-side shape, but on `USDJPY M5` it is sparse.
- The main problem is not only the stop/target example.
- Even after aligning the EA closer to the study, the edge remains too thin and too infrequent.
- For this doctrine, `long-only S1 continuation` is not a sufficient mainline by itself.

## Next Step

- Keep this family parked as a reference branch.
- Open the next fresh `USDJPY long-only` family from one of these theses:
  - round-number continuation long with stricter anti-chop rules,
  - volatility-state filtered breakout-follow-through long,
  - or a higher-resolution long continuation study if the doctrine needs more than `M5` granularity.
