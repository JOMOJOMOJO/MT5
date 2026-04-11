# USDJPY Method 2 EMA Continuation Reconfirm

- Date: `2026-04-10`
- Scope: `Method 2` candidate selection for the staged `USDJPY 3-method` build plan
- Candidate EA: `mql/Experts/usdjpy_20260402_ema_continuation_long.mq5`
- Candidate preset: `reports/presets/usdjpy_20260402_ema_continuation_long-london-loose.set`

## Reason For Selection

- The second method in this cycle must stay structurally different from the `round quality` mainline while remaining compatible with the same `USDJPY / M15` operating lane.
- Within the standalone `EMA13 / EMA100 continuation` family, `london-loose` is still the least-bad surviving branch.
- It is not strong enough to replace the mainline, but it is acceptable as a `research-qualified second bucket`.

## Reconfirm Result

- Compile:
  - `0 errors, 0 warnings`
- Train window:
  - `2025-04-01` to `2025-12-31`
  - `net +1057.57 / PF 1.12 / 88 trades / balance DD 12.46%`
- Recent OOS window:
  - `2026-01-01` to `2026-03-31`
  - `net +738.46 / PF 2.02 / 11 trades / balance DD 3.96%`

## Interpretation

- This branch still behaves like a useful sidecar:
  - more trades than the quality-first round method,
  - recent OOS remains positive,
  - but long-window train PF is still too weak for standalone promotion.
- Therefore:
  - keep `quality12b_guarded` as Method 1 and the only mainline,
  - keep `ema_continuation_long-london-loose` as Method 2,
  - do not call Method 2 `live-ready standalone`.

## Next Action

- Use the current `EMA continuation` branch as the fixed second method for future multi-method integration work.
- Do not merge a third method into the combined engine until that third method independently clears the repo gate.
