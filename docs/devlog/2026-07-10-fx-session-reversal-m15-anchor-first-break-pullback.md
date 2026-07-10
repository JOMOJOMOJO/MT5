# FX Session Reversal M15 Anchor First-Break Pullback

## Task

`ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` の M15 swing anchor bias を、押し安値/戻り高値の形成後に最初に終値で割った/抜いた足を基準に修正した。

## Changes

- `FindM15AnchorBreak` を first-after-anchor 探索に変更し、旧 latest-near-entry 相当は診断列として保持した。
- `m15_bias_flip_age_bars` を first break から entry 評価時点までの M15 確定足本数にした。
- true post-anchor pullback/retest 診断と required/score 用 input を追加した。
- `range_n` は今回の比較では hard gate にせず、診断だけに戻した。
- Q1 と 2025 通年用の固定比較スクリプトを追加した。

## Evidence

- Compile: `reports/compile/metaeditor.log` reports `0 errors, 0 warnings`.
- Backtest run root: `reports/backtest/runs/20260710_session_reversal_m15_anchor_first_break_pullback/`.
- Summary: `reports/backtest/runs/20260710_session_reversal_m15_anchor_first_break_pullback/summary.md`.
- Full comparison: `reports/backtest/runs/20260710_session_reversal_m15_anchor_first_break_pullback/full2025_comparison.csv`.

## Result

2025 shallow gate 通過候補は出なかった。

- `required-light`: 50 trades / PF 1.34 / avg_R +0.1099 / net +134.29。研究断片だが件数不足。
- `anchor_flip_first_break`: 122 trades / PF 0.76 / avg_R -0.0869。
- `anchor_pullback_required`: 73 trades / PF 0.90 / avg_R -0.0365。
- `light_or_anchor_pullback_m5pattern`: 104 trades / PF 0.96 / avg_R -0.0155。
- `one_light_or_anchor_pullback`: 60 trades / PF 1.28 / avg_R +0.0833。研究断片だが昇格不可。

## Decision

first-after-anchor 修正と true pullback/retest は実装上のズレ修正として妥当だったが、2025 通年では 100 trades 以上かつ PF>=1.05 / avg_R>0 の研究候補は出なかった。200 trades 以上の shallow gate 候補もないため、3年BT/OOSへは進めない。
