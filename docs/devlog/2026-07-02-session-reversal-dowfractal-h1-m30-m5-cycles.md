# Session Reversal Dow-Fractal H1/M30/M5 Cycles

## Task

The goal was to align `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` with a broader, multi-currency theory:

- Dow theory trend/range recognition on the upper context.
- Fractal nesting across three timeframes.
- A higher-timeframe third-wave or trend-bias context.
- A lower-timeframe third-wave turn, entered only after confirmation on the first pullback/retest.

## Code Changes

- Added ordered Dow pivot collection and trend/wave3 detection in `mql/Experts/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader.mq5`.
- Added H1/M30/M5 matrix presets in `scripts/generate-session-reversal-timeframe-matrix.py`.
- Added `InpTopContextTrendOnly`, `InpAllowStructureTrendBiasWhenNoWave3`, and `InpRequireRetestCloseBeyondNeckline`.
- Fixed pattern triggers so H&S and double-top/bottom setups report `neckline_break_retest`.
- Tightened the final cycle so the previous closed bar must break the neckline and the current bar must act as the retest/reclaim.
- Fixed `scripts/compile.ps1` to sync the compiled EX5 to the other installed MT5 terminal data folders. This corrected a real validation risk where one MT5 instance was still running an older EX5.

## Validation

Main evidence is stored under:

- `reports/backtest/runs/20260701_session_reversal_dowfractal_cycles/summary.md`
- `reports/backtest/runs/20260701_session_reversal_dowfractal_cycles/comparison.csv`
- `reports/backtest/runs/20260701_session_reversal_dowfractal_cycles/c6_full_cycle5_final/`
- `reports/backtest/runs/20260701_session_reversal_dowfractal_cycles/compile_metaeditor.log`

Final compile: `0 errors, 0 warnings`.

Final 2025 full-year check for the concept-correct cycle:

- 285 trades
- net -700.13
- PF 0.788
- avg_R -0.1046
- closed-trade max DD 831.72

## Decision

Do not promote this EA variant.

The final implementation matches the intended H1/M30/M5 Dow-fractal structure more closely than the previous "fractal-like" version, and it clears the 200-trade count. However, the edge is not present in 2025. The dominant failure is still post-breakout retest failure and full-SL frequency, especially `neckline_retest_failed`.

Break-even management did not repair the problem. The 1.1R mode worsened Q1 PF and avg_R while leaving full-SL count unchanged.

## Follow-Up

The next valid research direction is not symbol exclusion, direction-only trading, Friday stopping, or tiny parameter tuning. The next family should test a stricter retest-quality model: failed-breakout detection, displacement/volume proxy, reclaim hold time, or multi-bar acceptance after neckline retest.

