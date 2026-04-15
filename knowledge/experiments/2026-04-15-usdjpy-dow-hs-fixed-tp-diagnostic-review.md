# USDJPY Dow HS Fixed TP Diagnostic Review

Date: 2026-04-15

## Scope

- family: `Dow Fractal Head-And-Shoulders Reversal Engine`
- entry family: unchanged
- trade bias: `short-only`
- tier: `Tier A strict`
- trigger: `neck_close_confirm` only
- exit mode: `diagnostic_fixed_tp`
- pairs:
  - `M30 context x M15 pattern x M3 execution`
  - `M15 context x M10 pattern x M5 execution`
- TP grid:
  - `2 / 3 / 4 / 5 / 6 / 8` pips
- hold bars:
  - `16 / 24 / 32`
- windows:
  - train: `2025-04-01 .. 2025-12-31`
  - oos: `2026-01-01 .. 2026-04-01`
  - actual: `2024-11-26 .. 2026-04-01`

## Compile / Run

- compile: success
- run count: `108`
- second trigger was not expanded because the top-inventory trigger already failed the salvage test:
  - no `PF > 1` run anywhere
  - no repeatable OOS TP band

## Main Findings

### 1. OOS inventory did not survive

- `M30 x M15 x M3` produced `0` OOS trades across every TP / hold combination.
- `M15 x M10 x M5` produced only `1` OOS trade, and that single trade stopped out before even `2` pips MFE.
- Therefore, fixed TP does not create a repeatable OOS band. It only re-labels the same empty or losing OOS inventory.

### 2. Shallow TP did not rescue expectancy

- No run achieved `PF > 1`.
- Best actual run by report metrics was:
  - `M15 x M10 x M5`, `TP 8`, `hold 24`
  - `trades=31`, `PF=0.72`, `net=-40.25`, `expected payoff=-1.30`
- Next best actual run was:
  - `M15 x M10 x M5`, `TP 6`, `hold 24`
  - `trades=32`, `PF=0.57`, `net=-61.13`
- Best `M30 x M15 x M3` actual run was:
  - `TP 8`, `hold 16/24`
  - `PF=0.52`, `net=-63.45 / -64.43`

Shallow TP improved win rate, but it did not improve payoff enough to offset the structural stop and acceptance-loss profile.

### 3. The family is not scalp-positive even when trades often stretch a few pips

Representative actual telemetry:

| slice | cfg tp hit % | MFE median | MFE p75 | acceptance before TP % | time stop before TP % |
|---|---:|---:|---:|---:|---:|
| `M15 x M10 x M5`, `TP 2`, `hold 32` | 67.57 | 2.10 | 2.20 | 13.51 | 10.81 |
| `M15 x M10 x M5`, `TP 6`, `hold 24` | 54.84 | 6.00 | 6.10 | 16.13 | 25.81 |
| `M15 x M10 x M5`, `TP 8`, `hold 24` | 46.67 | 7.65 | 8.30 | 16.67 | 30.00 |
| `M30 x M15 x M3`, `TP 8`, `hold 24` | 26.47 | 4.45 | 8.00 | 35.29 | 29.41 |

Interpretation:

- `M15 x M10 x M5` does show that many trades can stretch `2-6` pips, and a minority can reach `8` pips.
- But the losing side is too expensive:
  - `TP 2`, `hold 32` still ended at `PF 0.36` with `72.97%` win rate.
  - `TP 8`, `hold 24` had the best actual profile, but still only `PF 0.72`.
- `M30 x M15 x M3` is worse on reach:
  - median MFE stays around `4-5` pips on the better `TP 8` slices
  - acceptance exits dominate the losing side

### 4. Larger TP was less bad than shallow TP

Actual aggregate by pair and TP:

- `M15 x M10 x M5`
  - `TP 2`: avg PF `0.33`
  - `TP 3`: avg PF `0.30`
  - `TP 4`: avg PF `0.32`
  - `TP 5`: avg PF `0.36`
  - `TP 6`: avg PF `0.42`
  - `TP 8`: avg PF `0.53`
- `M30 x M15 x M3`
  - `TP 2`: avg PF `0.35`
  - `TP 3`: avg PF `0.40`
  - `TP 4`: avg PF `0.41`
  - `TP 5`: avg PF `0.37`
  - `TP 6`: avg PF `0.41`
  - `TP 8`: avg PF `0.49`

This means the failure is not “target was too heavy.” The entry family does not become viable when compressed into `2-4` pip take-profit.

### 5. Hold `24` was usually the least-bad choice, not a rescue

Actual aggregate by pair and hold:

- `M15 x M10 x M5`
  - `hold 16`: avg PF `0.37`
  - `hold 24`: avg PF `0.41`
  - `hold 32`: avg PF `0.35`
- `M30 x M15 x M3`
  - `hold 16`: avg PF `0.41`
  - `hold 24`: avg PF `0.42`
  - `hold 32`: avg PF `0.40`

`24` bars is the cleanest hold choice, but it still does not cross into positive expectancy.

## Conclusion

`Reject`.

Reason:

- fixed TP did not produce a repeatable OOS band
- fixed TP did not create a single `PF > 1` run
- shallow TP did not rescue expectancy even when win rate improved
- the best actual slice remained negative
- `M30 x M15 x M3` stayed inventory-starved in OOS
- `M15 x M10 x M5` had only one OOS trade and that trade never reached even `2` pips

The evidence points to weak entry quality, not merely overweight exits.
