# Technical feature discovery: implementation and reproducibility

## Frozen research engine

The dedicated entry point is `mql/Experts/ExpectedValue_MultiCurrency_TickShockTechnicalResearch.mq5`.
It defines `TS_TECH_DISCOVERY` and includes the existing research EA. Five conditional
hooks capture an episode, observe its real ticks, initialize and finalize the new
observer. The existing detector, episode suppression and global watermark are not
replaced. The original EA still has no order submission path.

`mql/Include/TickShock/TickShockTechnicalFeatures.mqh` supplies both the terminal
adapter `TSTechCapture` and the synthetic-testable `TSTechBuildFromBars`.
The same computation produces all 486 features: 3 quote/direction values, 155
features on each of M1/M5/M15, and 18 cross-timeframe interactions. Feature order
is in the generated analysis `feature_catalog.csv`; formulas are in this module,
not a separate Python indicator implementation.

At most 256 completed Bid OHLC bars per timeframe are used. A bar is eligible
only when its open timestamp plus its timeframe is at or before t0. CopyRates
may return the containing bar; the builder explicitly excludes it. EMA and
Wilder recurrences are arithmetic-seeded on this bounded history, not asserted
identical to MT5's unlimited-history indicator handles. Historical percentiles
use up to 64 previous available observations (minimum 20; ties count 0.5).
Missing/zero-denominator values stay blank. Training-only median imputation is
part of each exported predictive model, never the feature producer.

Periods include EMA/SMA 5/10/20/50, RSI 7/14/21, ATR 7/14/28, MACD 12/26/9,
ADX/DI 14, Stochastic 14/3, CCI20, Williams14, Bollinger20, ROC 1/3/5/10/20,
range/efficiency 5/20/60, volume, candle and normalized relative interactions.
Raw price-level features are allowed by this development experiment; they can
implicitly identify a symbol, so feature importance is not proof of a universal
cross-symbol mechanism.

## Execution observer

`mql/Include/TickShock/TickShockTechnicalStudy.mqh` arms 12 shadow barriers per
episode: LONG/SHORT times six preregistered equal TP/SL distances. Entry is the
first subsequent same-symbol quote strictly after t0 and the source quote, and
not before recognition plus submit latency. Entry wait expires at t0+30s.
Buy pays Ask and exits Bid; Sell receives Bid and exits Ask. Distance is rounded
outward once and used symmetrically. Distance below 3 spreads is rejected without
widening. Broker protection distance uses the closing quote side.

TP fills at its limit; SL gaps use the observed executable price. TP/SL checks
precede TIME on the first quote at/after the 900-second deadline. During market
closures a position therefore remains open until another quote exists: the
900-second target is not a guaranteed wall-clock exit. The audit exports both
the maximum observed holding period and overruns. There is no interpolated fill.
Full-path 60/300/900-second excursions are observation-time diagnostics (the first
quote at/after a boundary), and may include the boundary-crossing quote. They are
labels only, never model features.

Storage is bounded: eight active episode records per symbol, six symbols. Only
one feature row and 12 finalized outcome rows are written per episode. No tick
or one-second series is written by the new modules. CSV files are fresh-only.

## Analysis and independent checks

`tools/tick_shock/analyze_technical_discovery.py` fits directional net-R models
using only the feature matrix. The bounded search is three model families,
six geometries, six absolute score thresholds and five training-score quantile
thresholds. Rejected entries are not relabeled as profitable alternatives. A
global pending/position reservation is processed in recognition-time order;
overlaps cannot inflate the reported monthly trade frequency.

Development-fitted performance and purged forward diagnostics are separate.
Chronological folds exclude labels extending into the validation period and
keep market clusters grouped. April is reused development, not OOS.
Six-symbol commission is NOT_OBSERVED. The primary 0.2-pip extra round-trip
allowance is a stress assumption, not an observed fee. Spread is already in
Bid/Ask P/L and is not subtracted twice.

`technical_discovery_independent_recalculation.py` uses CSV/JSON arithmetic and
independent model inference, without importing the analyzer or its ML libraries.
`audit_technical_discovery.py` compares episode identity/clocks/clusters to
Step15P, verifies formal dependency hashes and reports timing limitations.
`test_technical_discovery.py` has independent arithmetic/causality/portfolio and
exported-model tests. In strict JSON, non-finite PF is null; null is never zero.

## Commands

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/tick_shock/run_technical_harnesses.ps1 -TimeoutSeconds 120
python tools/tick_shock/test_technical_discovery.py
python tools/tick_shock/analyze_technical_discovery.py --features reports/backtest/runs/20260909_tstech_discovery_r2_202504/features.csv --outcomes reports/backtest/runs/20260909_tstech_discovery_r2_202504/outcomes.csv --output reports/analysis/tick_shock/technical_discovery
python tools/tick_shock/technical_discovery_independent_recalculation.py --features reports/backtest/runs/20260909_tstech_discovery_r2_202504/features.csv --outcomes reports/backtest/runs/20260909_tstech_discovery_r2_202504/outcomes.csv --output reports/analysis/tick_shock/technical_discovery
python tools/tick_shock/audit_technical_discovery.py --run reports/backtest/runs/20260909_tstech_discovery_r2_202504 --baseline reports/backtest/runs/20260908_ts15p_symmetric_oco_micro_profit_202504 --output reports/analysis/tick_shock/technical_discovery
```

The formal run command and actual preset, terminal/EX5/source hashes and report
are in `reports/backtest/runs/20260909_tstech_discovery_r2_202504/`. To repeat MT5,
choose a fresh unique RunId and output folder; never append to this evidence.
The earlier non-r2 attempt stopped at a PowerShell compile-return-code handling
error before starting MT5. That runner defect was fixed in d904b913; its partial
compile evidence was not deleted. It was not a second formal market experiment.

The inherited summary.csv contains legacy strategy results and hard-coded legacy
verdict strings. These are not the new RR1 technical outcomes or validation verdict.
Use `outcomes.csv` and the new analysis summary for this experiment.
