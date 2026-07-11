# FX Session Reversal M5 Micro-N Relaunch

## Durable Finding

M15押し安値・戻り高値のfirst close break後にtrue retestを待ち、さらにM5で確定した逆方向N波のanchor breakを待つ構造は、2025のsession first120 basketではentry母集団を改善せず、成立tradeを0件にした。

構造は次の順で未来参照なしに実装した。

1. 確定M15 anchorのfirst-after-anchor close break。
2. M15 break levelへのtrue pullback/retest。
3. 右側2本が閉じたM5 pivotによる `low-high-lower-low` または `high-low-higher-high`。
4. 中間の戻り高値/押し安値を終値でbreak。
5. break足または1本後までの最初のsignalだけを許可し、event IDで再利用を防止。

## Evidence

- [summary.md](../../reports/backtest/runs/20260711_session_reversal_m5_micro_n_relaunch/summary.md)
- [full2025_comparison.csv](../../reports/backtest/runs/20260711_session_reversal_m5_micro_n_relaunch/full2025_comparison.csv)
- [old_vs_micro_n_reconfirm_diff.csv](../../reports/backtest/runs/20260711_session_reversal_m5_micro_n_relaunch/old_vs_micro_n_reconfirm_diff.csv)
- [m5_micro_anchor_breakdown.csv](../../reports/backtest/runs/20260711_session_reversal_m5_micro_n_relaunch/m5_micro_anchor_breakdown.csv)
- [trades_all_scenarios.csv](../../reports/backtest/runs/20260711_session_reversal_m5_micro_n_relaunch/trades_all_scenarios.csv)

## Interpretation

- 旧reconfirmは39件のold-only bucketを作ったが、PF 0.38 / avg_R -0.2639で弱かった。
- 新micro-Nは旧reconfirmより定義が厳密だが、2025通年でfull entry chainを通過したtradeが0件だった。
- required-light OR micro-Nの50件はrequired-light単体と完全一致し、micro-Nの追加edgeではない。
- required-lightの50件はPF 1.34だが、USDJPY 62%、SHORT 72%、4/6 symbolsのみで、年間200件条件と分散条件を満たさない。
- one-symbol 35件のPF 1.74も低件数の選抜断片で、micro-N単体0件のため今回の仮説を支持しない。

## Reusable Lesson

構造gateを追加したとき0 tradesになった場合は、まず候補生成順序を監査する。後段gateとしてしか評価されていないtriggerは、trigger足そのものを候補化できない。候補順序を修正しても0件なら、その構造と時間窓の組み合わせが母集団を失わせている実証として扱い、細かな閾値緩和で延命しない。

## Family State

`ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` family: `parked`。

再開には閾値変更ではなく、session first120を前提にしない別family、またはM15 break前からM5 correction stateを継続管理する別の仮説が必要。現在のfamilyへ追加調整しない。
