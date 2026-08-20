# TRENDLINE_WAVE2_FAILURE execution接続・expiry shadow検証

## 結論

Protected Break検出とexecution candidate生成の責務を分離した。`TW2FM15WaitForProtectedBreak()`は確定足突破とMAフィルタだけを担当し、成功後の状態遷移・candidate生成・`candidate.valid`確認は`TW2FEvaluateM15()`が明示的に行う。

なお、修正前の実ファイルにもWait関数内部からの状態遷移とcandidate生成は存在していた。今回の修正は「未接続処理の新設」ではなく、呼び出し元が接続とvalidityを保証する構造への責務分離である。

## 実装後の接続

1. `TW2FM15WaitForProtectedBreak()`がclosed-bar protected breakとMA filterを判定する。
2. `TW2FEvaluateM15()`が`M15_CONTINUATION_FAILED -> M15_STRUCTURE_BROKEN`へ遷移する。
3. `TW2FBuildExecutionCandidate()`がexecution/risk gateを評価する。
4. valid candidate生成時に`ENTRY_READY`へ遷移する。
5. `TW2FEvaluateM15()`は`candidate.valid == true`の場合だけtrueを返す。
6. 実市場で到達した場合、events CSVへ`protected_break`、`M15_STRUCTURE_BROKEN`遷移、`ENTRY_READY`遷移、`execution_candidate_valid`を記録する。

## テスト

- Pattern classification reachability: 6 passed / 0 failed
  - Long/ShortのEqual、Higher Low/Lower High、False Break
  - 到達範囲は`M15_CONTINUATION_FAILED`までであり、full M15 testとは呼ばない
- M15 end-to-end state reachability: 2 passed / 0 failed
  - Long 1件、Short 1件
  - `H1_REVERSAL_LEG -> M15_PULLBACK_ACTIVE -> M15_CONTINUATION_FAILED -> M15_STRUCTURE_BROKEN -> ENTRY_READY`
  - `candidate.valid`、`stateIndex`、`direction`、`stopLoss`、`takeProfit`、`volume`をassert
- Compile: 0 errors / 0 warnings

## 2024再検証

- MT5 model: 4、Every tick based on real ticks
- History quality: 99% real ticks
- Ticks: 37,115,045
- H4 impulses: 80
- H1 mature: 4
- H1 trendline breaks: 1
- Live M15 anchor / protected break / execution pass / order: 0 / 0 / 0 / 0
- MT5 trades / deals: 0 / 0
- 固定戦略パラメータ差: 0

取引がないため、lot、SL、post-fill 2R、総リスク、通貨方向リスク、証拠金、MT5履歴と独自CSVの取引単位照合は今回も対象外である。

## H1 expiry shadow診断

shadowは注文関数とcandidate生成関数を呼ばない独立観測状態である。最大240 H1本の範囲で、2024年には1件を観測した。

| 項目 | 結果 |
|---|---|
| Setup | USDJPY Short |
| H1 break | 2024-03-05 16:00 |
| Expiry | 2024-03-08 17:00 |
| Expiry時M15 highs / lows | 7 / 7 |
| Expiry後最初のcounterStructure | 2024-03-11 23:30 |
| Counter時のH1 breakからの本数 | 103 |
| Counter時のexpiry後本数 | 30 |
| Shadow Anchor | 2024-03-11 23:30 |
| H1Wave1Origin破壊 | 2024-03-19 13:00 |
| Anchorは起点破壊前か | Yes |
| 240本以内にAnchorなし | No |
| Shadow注文試行 | 0 |

この1件では、既存expiry後30 H1本でAnchorが成立し、その後にH1Wave1Originが破壊された。ただし標本は1件だけなので、H1 expiryを72から延長する決定材料としては不十分である。今回は72を維持する。

## 未来参照・安全性

- 既存eventsのpivot/confirmation 243行で時系列違反0件
- shadowの`expiry < counter <= anchor < origin break`時系列違反0件
- shadow注文試行0件
- shadow実装ブロックからexecution candidate・注文処理への静的参照0件
- 2024年の実売買状態はM15 anchorへ到達していないため、実市場のprotected-break/candidate CSV行は0件

## Evidence

- [MT5 report](execution_shadow_2024/report.html)
- [Funnel and test counters](execution_shadow_2024/new_tw2f_execution_shadow_2024_summary.csv)
- [Runtime events](execution_shadow_2024/new_tw2f_execution_shadow_2024_events.csv)
- [Raw shadow CSV](execution_shadow_2024/new_tw2f_execution_shadow_2024_expiry_shadow.csv)
- [Shadow analysis](shadow_diagnostic_2024.csv)
- [M15 test summary](m15_test_summary_2024.csv)
- [Validation summary](validation_summary_2024.json)
- [Parameter diff](parameter_diff_2024.csv)
- [Run lock](run_lock.json)

2026年は再実行していない。
