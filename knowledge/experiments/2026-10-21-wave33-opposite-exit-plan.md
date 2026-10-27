# Wave33 v1.60：逆方向の①確定後、最初の推定プラスで決済

## 固定する変更

保有後に同じ時間足組み合わせの逆方向 `WAVE1_PEAK_CONFIRMED`（青い①の表示）が観測されたら、最初の根拠を保持する。現在のBid/Askで決済する損益＋既に計上された損益/手数料/費用＋残存スワップ－推定決済費用が厳密に0より大きい最初の実行可能ティックで成行決済を要求する。

- 検証する要因は `InpExitOnOppositeWave1=false/true` の一つ。RR1、認識2、①余地0.25R、上位足終値61.8%除外を固定。
- 第1波の固定/延長、エントリー、SL/TPを変更しない。未確定ブレイク候補を決済根拠にしない。
- 逆①が後で失効しても決済待ちを解除しない。プラスにならなければ元SL/TPへ従う。
- 通常チャートや他EAのポジションは変更しない。テスター内で銘柄・magic・position identifierが一致する実チケットだけを対象とする。
- コスト推定は観測済みの負のエントリー手数料/feeの単位数量あたり額を残数量へ適用。将来の決済費用・スリッページは未知なので実約定の正益を保証しない。

## 固定比較・合否

A: XAUUSD+、2018.02.01–2019.01.17、M15/M5。B: 同銘柄2019.01.02–17、M5/M1。各OFF/ON、5,000USD、レバレッジ100、Model4指定。旧v1.50と同じ開始日を保ち、候補蓄積差を混入させない。実ティックの有無はjournalで分類する。2026は使用しない。

合否は注文対象の同一性、約定後の逆①認識、知り得た時刻、最初のプラス判定、注文と約定の分離、重複要求の防止、SL/TPとの競合、実損益とRの整合。全保有・全候補を保存し、既存勝ち取引の利益を縮める場合も含める。総損益と共通エントリーの比較を分ける。閾値探索や成績を見た追加調整は行わない。

## 根拠と保存先

- [画像の第1波調査](../../reports/qa/wave33_opposite_exit_20261021/wave1_review.md)：07:30に局所高値を固定、その後の浅い押し後の伸長は未反映。アンカー変更は別の検証として残す。
- [設計レビュー](../../reports/qa/wave33_opposite_exit_20261021/design_review.md)
- 実行ファイル・ハッシュ・失敗も含む初回ビルドは `reports/qa/wave33_opposite_exit_20261021/`。Windowsパス長上限のため、最終ネイティブ実行は `reports/qa/w33opp/` に保存。
- 公式仕様：[OrderSend](https://www.mql5.com/en/docs/trading/ordersend)、[OnTradeTransaction](https://www.mql5.com/en/docs/event_handlers/ontradetransaction)、[Position Properties](https://www.mql5.com/en/docs/constants/tradingconstants/positionproperties)。送信受付と約定を分離し、position ticketとidentifierを区別する。
