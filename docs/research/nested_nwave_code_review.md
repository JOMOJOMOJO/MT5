# Nested N-Wave Code Review

Date: 2026-06-16

## Scope

Reviewed `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5` for branches and switches that can pull the EA away from universal fractal structure, N-wave, and Dow-theory logic.

This review does not propose a performance improvement. It separates universal strategy logic from research-only controls, deprecated short-window filters, and operational risk controls.

## Multi-Currency Baseline

The EA remains multi-currency capable.

- `InpSymbols` defaults to `USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD,XAUUSD`.
- `ParseSymbols()` splits `InpSymbols`, removes duplicates, calls `SymbolSelect(symbol, true)`, and populates `g_symbols`.
- `ScanAllSymbols()` iterates all `g_symbols`.
- `ScanThirdWaveSymbols()` iterates all `g_symbols` and evaluates both `LONG` and `SHORT` directions unless research direction mode blocks one side.
- `ScanNestedNWaveSymbols()` iterates all `g_symbols` and evaluates both `LONG` and `SHORT` directions unless research direction mode blocks one side.
- Mainline research defaults are `InpSymbolResearchMode=SYMBOL_RESEARCH_ALL`, `InpTradeDirectionMode=TRADE_DIRECTION_BOTH`, and `InpDisableUsdJpyShort=false`.

The symbol and direction research switches are still useful for decomposition, but they should not be treated as proof of a universal edge.

## Scan Clock Caveat

`RunNewExecutionBarScan()` uses `LatestClosedExecutionBarTime()`, and `LatestClosedExecutionBarTime()` currently reads the latest closed `InpExecutionTF` bar from `_Symbol`.

That means the scan clock is chart-symbol driven. In multi-currency testing this is usually workable when all symbols have aligned bars, but it can still create subtle behavior:

- non-chart symbols may have missing or delayed bars;
- the scan event may be triggered by `_Symbol` even if another symbol's latest closed bar is not synchronized;
- candidates are still evaluated per `g_symbols`, but the timing cadence is not per-symbol.

No scan architecture change was made in this cleanup. A diagnostic column `scan_driver_symbol` was added to scan diagnostics so future reports can see which chart symbol drove the scan cadence.

## Branch Classification

| Item | Classification | Decision |
|---|---|---|
| `ParseSymbols()` / `g_symbols` loops | A. Universal logic | Keep. This is the multi-currency framework. |
| `TRADE_DIRECTION_BOTH` | A. Universal logic | Keep as mainline default. |
| `SYMBOL_RESEARCH_ALL` | A. Universal logic | Keep as mainline default. |
| `InpTradeDirectionMode` | B. Research diagnostic | Keep for decomposition, but mainline evaluation should use BOTH. |
| `InpSymbolResearchMode` | B. Research diagnostic | Keep for decomposition, but mainline evaluation should use ALL. |
| `SYMBOL_RESEARCH_XAUUSD_ONLY` | B. Research diagnostic | Keep, but comment as research-only. |
| `SYMBOL_RESEARCH_FX_ONLY` | B. Research diagnostic | Keep, but comment as research-only. |
| `InpDisableUsdJpyShort` | B. Research diagnostic | Keep for old failure isolation, but comment as research-only and keep default false. |
| `IsXauSymbol()` | B. Research helper | Keep because research modes depend on it. |
| `IsUsdJpySymbol()` | B. Research helper | Keep because old USDJPY short diagnostics depend on it. |
| `Nested_NWave_NecklineBreak` | B. Research branch | Keep as baseline evidence branch. Not promoted. |
| `Nested_NWave_RetestConfirmation` | B. Research branch | Keep as diagnostic comparison. Not promoted. |
| `Nested_NWave_BreakoutQualityRouter` | B. Research branch | Keep as diagnostic comparison. Not promoted. |
| `Nested_NWave_ContextQualityRouter` | B. Research branch | Keep as diagnostic. It is a risk router, not an edge. |
| `Nested_NWave_ContextQualityRouterV2` | B/C. Diagnostic / rejected threshold branch | Keep for reproducibility, but do not continue threshold tuning. |
| `Nested_NWave_ContextQualityRouterV3` | C. Deprecated | Kept only as a compatibility alias to V2. Weekday/time risk logic removed. |
| `IsLateFridayNestedEntryRiskWindow()` | D. Removed | Removed from strategy logic. Friday cutoffs are external operation rules, not structural edge. |
| `weekend_entry_guard` | D. Removed | Removed from Nested expectancy path and counters. |
| `context_router_v2_weak_body_too_small` | C. Deprecated/rejected threshold branch | Kept only to reproduce V2. Not a direction for further tuning. |

## Cleanup Applied

- Removed the Friday 21:00+ nested entry guard from the EA strategy path.
- Removed `weekend_entry_guard` from Nested failure accounting.
- Kept `RESEARCH_STRATEGY_NESTED_NWAVE_CONTEXT_QUALITY_ROUTER_V3` for preset compatibility, but made it a deprecated V2 alias in naming and comments.
- Marked XAUUSD-only, FX-only, and USDJPY-short-disable switches as research-only in the code.
- Added `scan_driver_symbol` to scan diagnostics.

## Review Conclusion

The EA still supports multi-symbol, both-direction scanning. The dangerous part was not the multi-currency framework; it was the tendency to make short-window failures look better through weekday, symbol, direction, and narrow candle-threshold filters.

Nested Router work should be treated as negative evidence and diagnostic infrastructure. The next mainline research should redesign H4/H1 structure definition rather than add another M15 breakout threshold.
