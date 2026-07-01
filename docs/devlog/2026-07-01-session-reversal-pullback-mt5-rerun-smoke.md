# 2026-07-01 Session Reversal Pullback MT5 Rerun Smoke

## Task

Rerun `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` after the previous 2025 matrix attempt was blocked by MT5 account/history synchronization.

## Execution

- `C:\Program Files\XMTrading MT5 - 2\terminal64.exe` was used.
- This terminal mapped to data folder `D232275B22422903BD477FB48B858FBA`.
- The terminal synchronized successfully with `VantageTradingLtd-Live` account `32034651`.
- A 2025-01 smoke run and a full 2025 run both reached EA initialization and generated valid MT5 HTML reports.
- Repeated `history cache build error` lines appeared in the tester log, but they did not prevent completion.

## Result

Validated scenario:

- `london_first120__current__no_be`
- EA scenario: `london_first120_reference`
- Period: `2025.01.01..2025.12.31`
- Model: real ticks, M15
- Symbols: `USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD`

Summary:

- `signals=0`
- `orders_sent=0`
- `closed_trades=0`
- `final_equity=10000.00`
- `htf_permission_rejections=12384`
- `daily_stopped=false`
- `drawdown_stopped=false`

The strict H4/H1 HTF permission gate rejected all candidates for this London first120 reference run on this terminal/account data.

## Decision

The MT5 execution blocker is resolved for `XMTrading MT5 - 2`, but this single scenario has no tradable evidence because it produced zero signals and zero trades.

Do not promote `london_first120_reference` under `strict_h4_h1_alignment` from this run. The next useful rerun is either:

- a selected subset of relaxed HTF alignment scenarios, or
- the full 72-run matrix as a long batch, noting this one full-year scenario took about 10 minutes 53 seconds.

## Evidence

- `reports/backtest/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_london_first120__current__no_be_2025_report.html`
- `reports/backtest/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_london_first120__current__no_be_2025_report.html.meta.json`
- `reports/backtest/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_london_first120__current__no_be_2025_summary.csv`
- `reports/backtest/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_london_first120__current__no_be_smoke_relative_202501_report.html`
