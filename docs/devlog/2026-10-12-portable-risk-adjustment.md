# r5後の次工程：安全なvolume切下げを単独検証

ユーザーはr5最終報告に基づき最適と考える実施を委任。既知のロット拒否3件を対象に、上限リスクを緩めず小さいvolumeでの損失再評価を追加した研究版を作成した。

## 実装と分離

- `PortableRiskAdjustment.mqh`：従来PFMakePlanの正常処理を保持し、丸め後の予算超過だけを切下げ再評価する。
- `RelativeM5VolumeAdjustmentDiagnostics.mq5`：OFF/ON比較、追加CSV。売買EAや既存Sharedの変更なし。
- `PortableRiskAdjustmentHarness.mq5`：純粋な刻み計算＋各銘柄BUY/SELLの実API検査。
- prepare/analyze/test/runnerを追加。監査はOFF一致とONの因果的な差分を区別する。
- 既存compile.ps1は他terminalへのEX5同期を行うため、この研究では既存の独立・Hidden runner方式を継承し、本番への自動配置を避けた。

## 現時点の証拠

3ソースのコンパイル0 errors / 0 warnings。Python監査11項目合格。r5の3銘柄実データを新監査に通し、元データを保持したコピーで合格。
実MT5のOFF/ON比較は次の独立バッチで確認する。利益の改善や本番運用可能性はまだ主張しない。

## 完了後の確認

ユーザーの完了通知後、`20261012_221125_4ece6118` の12本完了・全監査合格を確認。実API harnessは16項目×3銘柄合格、当該バッチの3コンパイルも0 errors / 0 warnings。
旧版とOFFの売買は3銘柄で完全一致。ONはUSDJPYで4件の過大volumeを切下げ、予定損失を予算内に戻した。原本保護hash検査も合格。

USDJPYは49件のまま、−239.91→−211.96 USD、PF0.827→0.847。EURUSD/XAUUSDは変化なし。
4回復planのうち3件は早い候補への入れ替え（後続の保有・日次回数制限）で、1件はOFFと同じ実取引。入れ替え+25.12 USDと残高差による後続lot差+2.83 USDで差額を完全照合した。

実装QAは終了、研究版の既定OFF・本番未反映を維持。既知3か月の生成tick検証であり、正期待値・毎月20件・live-readyの判定ではない。

[最終報告・個別取引対応・再集計コード](../../reports/qa/portable_risk_adjustment_20261012/runs/20261012_221125_4ece6118/review/summary.md)

## 判断根拠

負の期待値の問題をリスク増大で覆わない。直近ゴールドだけの小幅プラスを根拠に銘柄や閾値を選ばない。
既存18設定探索の失敗を再探索しない。まず全銘柄へ再利用できる、小さく検証可能な執行改善を一つ閉じる。

[固定計画・API根拠・合格基準](../../reports/qa/portable_risk_adjustment_20261012/plan.md)

[前回の最終報告](../../reports/qa/portable_audit_20261012_r5/runs/20261012_120220_f6be2b8d/review/summary.md)

[過去18設定の見送り](../../knowledge/optimizations/2026-10-07-relative-continuation-18-cells.md)
