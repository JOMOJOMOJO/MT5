# ロット切下げ再計算：単独の執行改善

## 選んだ理由

ユーザーから[r5結果](../portable_audit_20261012_r5/runs/20261012_120220_f6be2b8d/review/summary.md)に基づく次の最適な実施を委任された。
今の証拠で根拠が最も明確な実装改善は、最小volumeでの損失から比例拡大したvolumeを再評価し、予算超過だった場合に切り下げて再計算すること。
USDJPYで確認した3件は一律見送りになっており、小さいvolumeなら予算内になる可能性がある。

この改善は期待値を作る仮説ではない。USDJPY/EURUSDはmid価格変化から負、ゴールドもPF1.052に過ぎず、リスク増大や良い銘柄だけの選抜は支持されない。
スプレッド/SL/RRの18設定は過去に全て不合格。今回その探索を再開しない。

## 変更点

- 新Include `mql/Include/Research/PortableRiskAdjustment.mqh` は既存PFMakePlanを呼ぶ。
- 既存プランがOKなら変更なし。他の拒否理由なら変更なし。
- `NORMALIZED_VOLUME_EXCEEDS_RISK` だけ、ON時にvolumeを必ず小さくする。
- 上限は「現在volume−1刻み」と「現在volume×予算/再計算損失」の小さい方。銘柄の刻みに切り下げる。
- 新volumeで `OrderCalcProfit` を必ず再実行。予定損失が予算以内になった場合に `OrderCalcMargin` を再実行し、自由証拠金以内だけOKとする。
- 最大32回。計算失敗、最小volume未満、上限回数は発注せず診断する。監査は未知/想定外理由を自動合格させない。
- 調整前後のvolume・予定損失・budget・理由・再計算回数を `adjustment.csv` へ保存。
- 別EA `RelativeM5VolumeAdjustmentDiagnostics.mq5`。`InpAdjustRoundedVolume=false` が既定。本番EA・従来Include・r5凍結ソースは変更しない。

予定損失は口座通貨による価格損失の試算であり、ギャップ等を含めた実現損失の絶対上限ではない。
[OrderCalcProfit公式定義](https://www.mql5.com/en/docs/trading/ordercalcprofit)、[OrderCalcMargin](https://www.mql5.com/en/docs/trading/ordercalcmargin)、[volume仕様](https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants)を確認した。

## 固定条件と実行順

- USDJPY/EURUSD/XAUUSD、USD口座10,000 USD、既存の許可済み独立MT5。
- M5 LONG、2023年1〜3月。既知期間の回帰・機能検証でありOOSではない。
- 元設定：リスク0.65%、SL2.2ATR、TP1.5R、最大18本、spread/ATR0.2。日次・口座停止等も固定。
- 同時にEntry、SL/TP、上位足、volume/shockフィルターを変えない。
- 新規12本：各銘柄harness3本＋旧版/OFF/ON×3銘柄の9本。
- 同じバッチで旧版も再実行し、現在のbroker仕様・履歴・費用とのペア比較を行う。以前の6本再利用手順とは別の、新しい機能比較。

## 合格基準（利益の符号とは独立）

1. 3銘柄harnessは各16項目合格：実USDJPY拒否値の切下げ例、最小volume、0.25刻み、invalid budget、各銘柄のBUY/SELL実OrderCalcProfit、OFF不変、ON再評価、証拠金再評価、他エラー非回復。
2. OFFは旧版と約定/SL/TP/volume/費用/risk.csv/環境診断が一致。
3. ONの受理planは予算内、volume増大なし、刻み・最小/最大volume内。実Entryは同一時刻のOK planと対応。
4. 全モードで元の各M5足のシグナル・spread・ATR列が一致。観測仕様、履歴fingerprint、実行バイナリを照合。
5. ONで売買差が出る場合、最初の調整後Entryより前の約定・費用は完全一致。以降はEquity/保有変化による後続volume/Entry可否の差を分けて報告する。
6. nativeレポートとの全deal/損益照合、終端履歴回収、未来足不使用の既存観測チェックを維持。

## 発進前確認

- [コンパイル](preflight/20261012_220803_9d3b8845/)：3ソースとも0 errors / 0 warnings。
- Python監査11テスト合格。過大volume・予算超過・OFF中変更・別理由の回復・調整以前の売買差を拒否。
- [保存済み実データの新監査](preflight/known_evidence/)：3銘柄とも合格。元runは書き換えていない。
- 元EA/Sharedの保護hashと全r5凍結証跡を確認。

## 完了後

この短期QAだけで本番採用・収益性昇格はしない。回復planの発注・収益、後続の影響、予算利用率を報告し、共通執行部としての改善可否を決める。
別の上位足仮説を評価するなら、この機能変更と混ぜず、事前に別の母集団・期間を固定する。
MT5起動後は待機やポーリングを続けずターンを終了し、ユーザーの完了通知後に確認する。
