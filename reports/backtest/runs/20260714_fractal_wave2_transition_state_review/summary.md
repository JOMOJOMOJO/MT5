# Fractal Wave2 Transition State Review

## Scope
- 対象は新EAのみ。旧 `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` は変更していない。
- M15/M5 pivotは左右 `InpPivotDepth` 本が閉じた後だけ利用する。未確定足・未来参照・repaint ZigZagは使わない。
- tester=M15だがscanは各symbolのM5確定足更新で実行する。H1=16385、M15=15、M5=5をpresetで確認した。
- `[Experts] Enabled=0`、`AllowLiveTrading=0`、Model=4、Deposit=10000の固定run。

## Full 2025 Trade Runs
- Mode 0: 177 trades / PF 0.70 / avg_R -0.1261 / net -526.49 / MFE>=1R 20.3%
- Mode 1: 165 trades / PF 0.69 / avg_R -0.1292 / net -518.27 / MFE>=1R 20.0%
- Mode 2: 173 trades / PF 0.69 / avg_R -0.1313 / net -546.18 / MFE>=1R 19.7%
- Mode 2 parent-stop reference: 31 trades / PF 0.99 / avg_R -0.0068 / net -3.83 / MFE>=1R 35.5%

## Required Answers
1. 修正前のM15 wave2開始は、parent break後に前足終値と逆方向へ動いた最初のM15 closeだった。
2. はい。逆方向close 1本だけで `PARENT_WAVE2_ACTIVE` へ遷移していた。
3. `PARENT_WAVE2_PENDING` と `SIGNAL_RESERVED` を追加した。pending親は確認待ち中に新しい親候補へ不正置換されない。
4. 通年wave2開始数は Mode 0=4504、Mode 1=4319、Mode 2=3963。
5. 修正前 `UpdateChildTrend()` は最古から走査し、最初に成立した3-pivot構造とanchorを使っていた。
6. 修正後は確定pivotのみで新安値/新高値ごとに最新有効anchorを版管理し、旧anchorを置換する。
7. first/latest anchorが異なったparent eventは 2063 件。
8. 修正前相当では旧anchor flipが 795 件あった。latest modeでは取引がすべて最新anchorだが、同一signalの反実仮想ではないため損益の単独因果は断定しない。
9. Mode 2 child countertrend成立数は 4373。
10. Mode 2 child anchor作成数は 3964。
11. Mode 2 child anchor更新数は 4160。
12. Mode 2 child flip数は 3143。
13. Mode 2 fresh first flip数は 3142。
14. Mode 2 candidate validationは有効=174、失効=2968。理由は candidate_invalid_invalid_stop_distance=406, candidate_invalid_spread_guard=2562。portfolio rejectionとは分離した。
15. 技術無効は `invalid_candidate`、有効候補は `before_portfolio` で予約し、その後をposition/risk/order/tradedに分離した。
16. 実trade数は Mode 0=177、Mode 1=165、Mode 2=173。
17. mode別成績: Mode 0 177 trades / PF 0.70 / avg_R -0.1261 / net -526.49 / MFE>=1R 20.3% / Mode 1 165 trades / PF 0.69 / avg_R -0.1292 / net -518.27 / MFE>=1R 20.0% / Mode 2 173 trades / PF 0.69 / avg_R -0.1313 / net -546.18 / MFE>=1R 19.7%。
18. 研究継続条件通過: none。
19. 2025 shallow gate通過: none。
20. 3年BT/OOS: 実施しない。2025 gate未通過。

## Code Review Findings
- Mode 1が初回Q1で0件になった原因は、pending親がterminal pivot確定前に新parentへ置換される状態機械バグだった。親確認窓を保持して修正し、全runを再実行した。
- candidate invalidは再評価ごとに重複計数せず、parent signalごとに一度失効するよう修正した。
- 最新anchorの最初の終値breakだけをfresh signalとし、過去breakの再利用は `stale_child_flip_not_reused` として失効する。

## Decision
- 2025 shallow gate通過候補なし。3年BT/OOS、demo/live、細かい閾値最適化へは進めない。
- 修正前相当diagnostic child flips=2101、latest Mode 2 diagnostic child flips=3143。
