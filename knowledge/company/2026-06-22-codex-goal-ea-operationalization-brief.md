# 2026-06-22 Codex Goal EA Backtest-Only Brief

## Purpose

Use Codex Goal mode for one durable objective: build or select a multi-currency MT5 EA candidate and validate it only with MT5 backtests. Do not include demo-forward, live, or first-capital operations unless the user explicitly changes the objective.

## Current Asset Read

- The repo is evidence-rich: most files are under `reports/`, with many MT5 reports, CSVs, presets, tester configs, screenshots, and machine-readable JSON artifacts.
- The active USDJPY operational mainline is `quality12b_guarded`, documented in `.company/release/usdjpy_20260402_round_continuation_long-quality12b_guarded.md`.
- The turnover-biased USDJPY comparison branch is `quality12b_stack_parallel_guarded`, documented in `.company/release/usdjpy_20260402_round_continuation_long-quality12b_stack_parallel_guarded.md`.
- The current BTCUSD secondary live-track candidate is `bull37_long_h12_live035_guarded2`, documented in `.company/release/btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2.md`.
- The latest multi-currency structure research is parked as a preserved research asset, not an active tuning branch. See `docs/research/multicurrency_score_scanner_research_closure_2026-06-22.md` and `docs/research/next_ea_idea_bank_from_multicurrency_research.md`.

## Recommended Goal Route

Start with the repo's multi-currency research assets and diagnostics, but do not assume the latest `ExpectedValue_MultiCurrency_ScoreScanner` logic is already promotable.

Rationale:

- The user wants one EA that monitors multiple symbols and can trade across multiple instruments.
- The minimum operating target is `200+ trades/year`.
- The latest multi-currency structure research was parked as an active branch, but it preserved useful framework assets: symbol scanning, diagnostics, R metrics, all-candidates mode, and failure decomposition.
- Existing single-symbol USDJPY/BTCUSD release packets can inform risk and QA discipline, but they should not define the next goal.

## Suggested Codex Goal Shape

Use `/goal` with one objective and a verifiable stopping condition.

Example:

```text
/goal Build or select a multi-currency MT5 EA candidate and validate it only with MT5 backtests. Do not include demo-forward, live, first-capital, or operator workflow. Read docs/research/multicurrency_score_scanner_research_closure_2026-06-22.md, docs/research/next_ea_idea_bank_from_multicurrency_research.md, knowledge/lessons/multicurrency_structure_research_lessons_2026-06-22.md, .company/strategy/charter.md, .company/qa/checklist.md, scripts/compile.ps1, and scripts/backtest.ps1 first. Use existing multi-currency scanner code and reports as assets, but avoid continuing a parked weak branch unless evidence supports it. The EA must monitor multiple liquid symbols, be capable of trading multiple symbols, and target at least 200 closed trades/year in fixed-parameter MT5 validation. Validate with a short search window, then locked fixed-parameter long-window backtests and explicit OOS windows. Stop only when there is a candidate with archived MT5 backtest artifacts meeting the acceptance floor, or a written rejection explaining which condition failed.
```

## Guardrails For The Goal

- Do not add demo-forward, live, first-capital, heartbeat, or operator-control tasks.
- Do not use a single-symbol candidate as the final answer.
- Do not accept fewer than `200 closed trades/year` unless the user explicitly relaxes that floor.
- Do not promote a result that depends on one symbol, one side, or one year.
- Do not tune many parameters against one window and call it edge.
- Treat `3% risk` as daily or portfolio hard-loss budget unless explicitly approved otherwise.
- Judge the candidate primarily in R, expectancy, PF, drawdown, and sample size, not win rate.

## If Opening A New EA Family

Use the parked multi-currency research as design input, not as an incremental continuation.

Preferred first new-family thesis:

- `STRUCTURAL_CONTEXT_BOS`
- H4/H1 context first
- M15 execution second
- true countertrend structure invalidation
- room-to-1R and room-to-2R diagnostics from day one
- no symbol, direction, or weekday escape filters as promotion logic

Validation ladder:

- short diagnostic windows first
- then fixed 9-month train / 3-month OOS
- then annual and multi-year checks
- only then demo-forward

## Decision

For the next Codex goal, choose one of these paths:

1. Backtest-only multi-currency path: build or select a `200+ trades/year` candidate and validate it with MT5 fixed-parameter train/OOS artifacts.
2. Research path: build a separate `STRUCTURAL_CONTEXT_BOS` prototype from the parked multi-currency lessons.

Do not combine backtest-only candidate validation with demo/live operations in one goal.
