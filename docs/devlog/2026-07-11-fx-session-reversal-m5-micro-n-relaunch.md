# M5 Micro-N Relaunch Final Structure Validation

## Task

`ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` に、M15 first-after-anchor break と true pullback/retest の後で形成されたM5の小さいN波を使うentry triggerを追加した。

Longは確定pivotによる `low-high-lower-low` の下降Nを作り、中間の戻り高値を終値で上抜いた最初の確定足を候補にする。Shortは `high-low-higher-high` の上昇Nと中間の押し安値breakで対称実装した。pivotの右側確認足が閉じる前の値、未確定足、MFE/resultはentry条件に使っていない。

## Implementation Notes

- `InpM5PostAnchorRelaunchMode` に off / diagnostic / score / required / required-first-signal-only を追加した。
- M15 break event ID とM5 micro anchor event IDを記録し、first-onlyでは候補確定時にイベントを予約消費する。候補選抜、position cap、risk blockで発注できなくても古いsignalを後から再利用しない。
- entry timing、micro anchor、break品質、signal age、消費・失効状態をsignals/trades CSVへ追加した。
- 初回Q1/2025実行で、既存M5 pattern候補の後にmicro-Nを評価していたため、micro-N break自体が独立候補にならない判定順序を発見した。required系ではmicro-N breakから直接 `m5_micro_n_relaunch` candidateを作り、M5押し安値/戻り高値をstop anchorへ渡すよう修正し、Q1と2025の該当runを再実行した。

## Verification

- Compile: `0 errors, 0 warnings`。証跡は [compile.log](../../reports/backtest/runs/20260711_session_reversal_m5_micro_n_relaunch/compile.log)。
- Preset timeframes: H1=`16385`, M15=`15`, M5=`5`。
- Tester periodはM15だが、全1,329 tradeで `selected_candidate_timeframe=PERIOD_M5` と `primary_entry_tf=PERIOD_M5` を確認した。
- Tester INIは `Enabled=0`, `AllowLiveTrading=0`。
- 26 runすべてMT5 report、preset、tester INIを保存した。
- 集計と固定結果は [summary.md](../../reports/backtest/runs/20260711_session_reversal_m5_micro_n_relaunch/summary.md) と [full2025_comparison.csv](../../reports/backtest/runs/20260711_session_reversal_m5_micro_n_relaunch/full2025_comparison.csv)。

## Result

- baseline: 318 trades / PF 0.59 / avg_R -0.1582 / net -1144.89。
- required-light: 50 trades / PF 1.34 / avg_R +0.1099 / net +134.29。
- previous anchor pullback: 73 trades / PF 0.90 / avg_R -0.0365 / net -55.75。
- M5 micro-N required / first-only / strong: すべて0 trades。
- required-light OR micro-N: required-lightと同じ50 tradesで、micro-Nの追加寄与は0。
- one-symbol OR: 35 trades / PF 1.74 / avg_R +0.2133だが、micro-N由来ではなくrequired-light由来で、昇格不能。

## Decision

100 trades以上・正の期待値・baselineより明確なMFE改善という最終停止条件を満たさなかった。200 trades以上の2025 shallow gateも未通過で、3年BT/OOSは実施していない。

このEAファミリーは `parked` の研究資産として保存し、同じ思想への追加の閾値調整・indicator追加・通貨/方向/曜日限定を停止する。
