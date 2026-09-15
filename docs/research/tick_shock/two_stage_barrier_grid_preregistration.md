# Fixed barrier-grid experiment — user approved 2026-09-14

TP {0.40, 0.50, 0.68} × SL {0.25, 0.40, 0.55}, in completed M5 ATR14
frozen at signal. All nine cells are run; no result-dependent expansion/selection.
Period July 1–September 1, 2025, six symbols, EURUSD M1 driver, Model 4.
July/August are now observed development/exit-selection data, NOT unused OOS.

Frozen two-stage model, feature generation and detector unchanged. The model
predicts 5-minute returns, not these barrier outcomes; this is an exit experiment.
TP rounds outward; SL rounds inward to tick size, never wider. Order-time protective
SL/TP are submitted together. Fill correction anchors TP to actual fill and can
tighten SL but never widen it. Broker/price/margin failures skip; no automatic
spread-multiple widening and no new 3×spread filter.

Four-hour time safety exit remains, subject to market availability. Fifteen-minute
global entry interval measured from previous actual fill. A new shock signal is
required; skipped signals are not queued for entry fifteen minutes later.
No fixed concurrent-position cap. Dynamic active-record storage is released on
full close. One pending entry is resolved at a time. Hedging accounting is mandatory;
netting fails initialization rather than merging independent positions. Signals may
produce opposite positions when the account permits; no forced opposing pair is opened.

Risk budget per trade: min(10 USD, 0.25% current equity), calculated to actual SL
with OrderCalcProfit, volume rounded down. No portfolio risk cap is asserted;
peak concurrent count and sum of modeled SL losses are recorded. Gaps, slippage,
fees and inability to close can exceed planned loss. Tester-only, not live-ready.

First compile and deterministic geometry/spacing tests; then a January 2–4 wiring
smoke. Test-only forced-intent harness verifies multiple ticket isolation; it is
separate from the production EA. Formal nine-cell runs only after gates pass.
Each unique run stores inputs, source hashes, trades, actions, summary and HTML.
Stop on incomplete evidence/nonzero integrity errors. No overwrite/resume by default.

New EA: `mql/Experts/ExpectedValue_TickShockTwoStageBarrierCandidate.mq5`.
The previous time-only candidate and frozen model files are not modified.
