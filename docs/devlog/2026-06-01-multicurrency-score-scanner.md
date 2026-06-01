# 2026-06-01 - Multi-Currency Score Scanner

## Summary

- task: create a multi-currency MT5 EA that scans several symbols from one chart
- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- status: initial diagnostic scaffold implemented and compiled; trading is disabled by default

## Design

- `InpSymbols` is parsed as a comma-separated list during `OnInit`.
- Each valid symbol is added to Market Watch with `SymbolSelect(symbol, true)`.
- `EventSetTimer` drives periodic scans through `OnTimer`.
- Each scan loads `InpContextTF`, `InpPatternTF`, and `InpExecutionTF` data with `CopyRates`.
- Symbols with insufficient data are skipped and logged with an explicit reason.
- Each symbol is scored on both long and short sides, then the higher side is retained.
- The best score across symbols is marked as `best_candidate` in the CSV reason field.

## Score Model

The initial model is intentionally simple and replaceable:

- `trendScore`: context and pattern MA alignment plus slow MA slope
- `setupScore`: pullback/recovery, breakout, momentum candle, and execution confirmation
- `volatilityScore`: current pattern ATR versus average pattern ATR
- `costPenalty`: spread divided by execution ATR
- `riskPenalty`: current managed positions, same currency group exposure, open risk, and hard risk stops

`totalScore = trendScore + setupScore + volatilityScore - costPenalty - riskPenalty`.

## Risk Posture

Following the repo risk-manager guard-rail, live execution starts locked behind `InpEnableTrading=false`.

Default live-bridge limits are conservative:

- per-trade risk: `0.50%`
- per-symbol open risk cap: `1.00%`
- total open risk cap: `3.00%`
- daily equity loss stop: `3.00%`
- weekly equity loss stop: `6.00%`
- max drawdown stop from EA peak equity: `10.00%`
- same currency group cap: `1`

The first version uses equity anchors while the EA is running. A future live candidate should add persistent realized-PnL state and backtest evidence before enabling orders.

## Output

CSV rows are written to `logs/multicurrency_score_YYYYMMDD.csv` under the terminal Files directory unless `InpUseCommonFiles=true`.

Columns:

`time,symbol,direction,totalScore,trendScore,setupScore,volatilityScore,costPenalty,riskPenalty,reason`

## Evidence

- compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner.log`
- compile result: `0 errors, 0 warnings`
