# 汎用化QA r3：同じバッチの旧版と修正版を比較

ユーザーの「実施して」により[次段階の提案](../portable_audit_20261009_r2/next_steps_proposal.md)の第一段階を実行する。
過去の失敗runや照合ルールを上書きしない。本番EA・Shared・既存研究ソースの変更はない。
今回追加したコードは研究用の観測Include、凍結QAソース、実行・分析スクリプトのみ。

## 変更点

1. 過去レポートのみとの費用比較に加え、旧日足EAを同じバッチで新たに実行する。
2. 新旧の全EAへ同じread-only観測を追加。売買入力・売買関数本体は維持。
3. 売買と費用を別の合否項目にする。総合合格は両方の一致が必要で、0.05 USDの差を許容する変更ではない。
4. 旧レポートとの差は `historical_comparison.json` へ保存。新しい同バッチ対照との一致は `pair_audit.json` で判定する。

### 観測ファイル

- `environment.csv`：口座通貨・leverage・margin方式、base/profit/margin通貨、contract、tick、lot制約、注文仕様、swap方式・long/short・曜日倍率。
  開始、終了、各利用可能分の変化時に保存。途中で仕様の変化が見つかれば不合格。分内の変更・復帰までは検出保証しない。
- `conversion.csv`：各dealの収集時刻、quote時刻、tick value、最小lotで100tick動いた場合の口座通貨損益試算。
  後から回収したdealの試算は収集時点の値であり、過去の約定時点の値として扱わない。換算情報の診断専用。
- `history.csv`：終了後だけ、2021-01-01〜2023-03-31のM1/M5/M15/H1/H4/D1を価格・volume・spread込みでfingerprint化。
  FNV64であり暗号学的証明ではない。全tick列の一致証明でもない。指標のwarm-upを含む足データを新旧で比較するために使用。
- `cost.csv`：全約定の監査。HTML・CSV・position対応・実損益の一致は従来通り必須。

取得する銘柄属性は[MetaQuotes公式](https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants)、口座通貨損益は[OrderCalcProfit](https://www.mql5.com/en/docs/trading/ordercalcprofit)に従う。

## 固定10本

1. harness：発注なし18項目
2. daily_reference：旧日足EA、新しいバッチで実行
3. daily_legacy_clock：修正版、旧時計。2との完全一致を要求
4. daily_timer：修正版、独立timer。時計差は記録し、2/3との売買一致を強制しない。終了時の決済回収を確認
5–10. M5 USDJPY/EURUSD/XAUUSDの各旧版・修正版

期間は前回と同じ2023年1〜3月（harnessは1月1〜6日）。パラメータ探索なし。
M5はSL2.2ATR、TP1.5R、risk0.65%、spread/ATR0.20、日足risk0.25%を維持。
旧日足の5銘柄構成も維持。XAUUSDだけrisk上限を上げたり最低lotへ切り上げない。
いずれも既知期間の工学QAであり、OOS・利益改善研究ではない。

## 対照ペアの合格条件

- 候補列が一致。日足はSIGNALのtime/price/channel/ATR、M5はCANDIDATEの全既存環境・制御列。
- Entry/Exit時刻・価格・volume・SL/TP・方向・理由が一致。
- profit/commission/swap/feeが一致。
- 観測した銘柄仕様、足履歴fingerprint、MT5バイナリが一致。
- 各run内の仕様変化、記録欠損、重複、因果違反がない。
- 成績が正であることはQAの合格条件に含めない。

今回比較で元のswap差の歴史的原因まで自動的に確定できるとは限らない。過去runで保存していなかった条件は推測で埋めない。
失敗時は次のrunへ進まず停止。起動後Codexは待機せず終了し、ユーザーの完了連絡後に成果物を確認する。

## 事前確認

- Python回帰テスト15件合格。実データのswap-only差は「売買一致・費用不一致」と判定し、欠損決済も引き続き拒否。
- [コンパイル](preflight/20261009_162020_9f21c7f6/status.json)：5ソース全て0 errors / 0 warnings。
- スクリプト構文、凍結hash、既存本番ソースの保存を確認。
- Entry意図とコードの対応は[別メモ](signal_definition_review.md)に整理。新しい売買条件は未追加。
