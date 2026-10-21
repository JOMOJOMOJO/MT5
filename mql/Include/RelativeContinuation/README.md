# RelativeContinuation v2

Successor EA: `mql/Experts/RelativeContinuation.mq5`. New ATR-normalized schema; do not reuse the quality12b `.set` file.

All `*Atr` price widths refer to **InpSignalTimeframe closed ATR(InpDistanceATRPeriod)**, even for optional lower-timeframe buckets. Risk and cap inputs are percentages of account equity. Reward inputs are R multiples. Other dimensions are candle fractions, oscillator levels, percent returns, bars and broker-server hours.

Configuration holds inputs/state; RuntimeRisk handles ATR, sizing and caps; ExecutionSafety handles persistent/reconciled state and funnel logs. MarketData loads full windows; PriceStructure and Signals retain the inherited hypotheses with normalized distances. Orders applies broker constraints; PositionManagement manages occupancy/exits; TelemetryControl writes operational logs.

Default study uses one round-long bucket / one position on USDJPY M15. Multi-currency means one chart instance per symbol, not a multi-symbol scanner. Gold and other contracts need validation. See `reports/qa/rc_search_20261007/plan.md` and `reports/qa/relative_continuation_20261006/review.md`.
