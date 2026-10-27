# Wave33 v1.60：逆方向の①を知った後、最初の推定プラスで決済

v1.60のEAとA/B設定を配置済み。既存の他EAは変更していない。逆方向の青い①が保有後に確定したら、元のSL/TPを保持して決済待ちへ入り、最初の実行可能なプラス見積りで決済を要求する。通常口座チャートでの注文・決済は行わない。

この変更は第1波の認識・エントリー・RRを変えない。画像の①が早い局所高値で固定された件は[別の画像調査](../wave33_opposite_exit_20261021/wave1_review.md)に残した。11月15日06:45の1212.23を07:30に固定し、浅い25.8%の押し後の高値更新を取り込んでいなかった。後の1216.46へ延長しても、その後の下落は61.8%を超えるため、有効な買いになったとは断定しない。

## 使う設定

- [A：M15×M5](../../presets/wave33-v160-A-M15-M5-orders.set) / [ビジュアルINI](../../backtest/wave33-v160-A-M15-M5-orders-visual.ini)
- [B：M5×M1](../../presets/wave33-v160-B-M5-M1-orders.set) / [ビジュアルINI](../../backtest/wave33-v160-B-M5-M1-orders-visual.ini)
- [MT5の操作と入力説明](../../../docs/validation/wave33-tester-orders.md) / [配布ファイルとハッシュ](deployment.json)

テスターを停止し、`dev\mql\Experts\Wave33VisualVerifier.ex5`を選び直して新SETを読む。`InpEnableTesterOrders=true`、`InpExitOnOppositeWave1=true`。通常プリセットの全ティック監査はOFFで、必要なら `InpAuditOppositeExitTicks=true` とする。旧設定は履歴として保持する。

## 決済の定義

- 同じ上位足・下位足の組み合わせで、実際の約定後に観測した `WAVE1_PEAK_CONFIRMED` が対象。反対波の過去の位置に遡って決済しない。同秒内もイベント順序で前後を区別する。
- 一度記録した最初の逆①を保持し、その候補が後で失効しても待機を継続する。判定前からある逆①は使わない。
- 推定純損益＝現在の決済側Bid/Askの価格損益＋計上済み損益/手数料/fee＋残存スワップ－推定決済費用。厳密に0より大きいティックで要求する。
- 決済費用は負のエントリー手数料・feeの単位数量あたり額から推定する。将来費用・滑りは未知で、実約定の厳密なプラスを保証しない。
- 銘柄・magic・position identifierで現物を確認し、現在のposition ticketへ決済を送る。要求受付、拒否、部分約定、実決済を分離する。要求中に重複発注しない。拒否・部分決済の残りは次の適格ティックで再確認する。
- 黄色の「逆①：プラス決済待ち」と「EXIT 逆① 利益決済」を描く。専用理由は `OPPOSITE_WAVE1_PROFIT`、生の理由は `exit_deal_reason`。source ID、波の位置、知った日時、費用見積り、実現純損益と当初リスクをCSVへ記録する。

送信受付と実約定の区別、position ticketとidentifierの扱いは [OrderSend](https://www.mql5.com/en/docs/trading/ordersend)、[OnTradeTransaction](https://www.mql5.com/en/docs/event_handlers/ontradetransaction)、[Position Properties](https://www.mql5.com/en/docs/constants/tradingconstants/positionproperties) に基づく。

## 固定比較：良い例と悪い例の両方

XAUUSD+、USD口座、5,000USD、レバレッジ100、RR1、下位認識2、①余地0.25R、上位足終値61.8%除外を固定。OFF/ONで変更する売買入力は逆①決済だけ。各条件の全候補を保存する。

| 組み合わせ・期間 | OFF 約定 | ON 約定 | 逆①待機 | 専用決済 | 待機したがSL |
|---|---:|---:|---:|---:|---:|
| A M15/M5、2018.02.01–2019.01.17 | 21 | 22 | 5 | 3 | 2 |
| B M5/M1、2019.01.02–17 | 12 | 13 | 4 | 4 | 0 |

全候補はA各208、B各45。前倒し決済により後続の保有制限が解除され、各ONで1件ずつ発注が増えた。追加取引と共通取引を分けて比較した。

| 共通取引の合計R | OFF | ON |
|---|---:|---:|
| A：共通21件 | -6.792124 | -4.904094 |
| B：共通12件 | +1.280726 | +2.592861 |

Aは損失が小さくなったが負のまま。Bの1月8日SHORTは従来+0.967105Rから+0.046053Rへ利益を縮めた。AのSHORT1件は値幅損でも正のスワップ込みでプラスになっており、価格だけの建値回復とは異なる。[全待機9件の事例表](a_case_review.md)、[A独立監査](aaudit/README.md)、[B独立監査](baudit/README.md)を参照。収益性の採用判定や閾値探索は行っていない。

## 時刻・描画の確認

Aは待機した5件すべて、Bは待機4件＋時系列で最初の通常約定1件。勝ち負けで選んでいない。

- [A 5事例・認識時刻](imgAf/fixture_cases.md) / [画像一覧](imgAf/render_summary.csv) / [描画監査](a_drawing_audit.json)
- [B 5事例・認識時刻](imgB/fixture_cases.md) / [画像一覧](imgB/render_summary.csv) / [描画レビュー](b_drawing_review.md)
- [A描画の出所](imgAf/provenance.json) / [B描画の出所](imgB/provenance.json)

PNGは通常チャートにネイティブCSVを再生した描画で、テスター画面の直接キャプチャではない。実M1のうちcutoffまでに確定した足だけを登録し、秒単位のEXITを含む未完了の最終M1は省く。EXITの時刻・価格は実約定値を描く。シグナル再計算はしない。初回Aの最後の未完了M1が混入し得た[修正前の画像](imgA/CAUTION_BEFORE_PARTIAL_M1_REPAIR.md)も保存し、最終Aは `imgAf` とする。

## 検証の範囲

- 最終QAのEA＋7ハーネスを0 errors / 0 warningsでコンパイル。既存ロジックと新決済・表示の計637項目PASS、失敗0。[最終実行](final/20261022_000609_1f6049d6/) / [集計・配布ソース整合](engineering.json)。
- テスター内で読み戻せないtooltip4項目をUNAVAILABLEとして明記し、PASSへ算入しない。実際の通常チャートのオブジェクト一覧でsource ID、波の位置、known時刻、実決済価格・Rを別に確認する。
- Aの5画像は親、Bの5画像は独立担当が全件目視した。通常チャートの描画監査はA93/B97項目PASS。B0/B3の共通転換点で従来の①と②の文字が重なる点は残るが、新しい黄色の待機・EXITは読める。
- A/B独立監査は合計431,487 checks、違反0、不足0。記録された待機ティックの損益計算、初回プラスと送信、native reportの実金額/R、識別子、決済注文番号、上位足と候補の前半の同一性を照合した。外部データ供給の完全性そのものを証明するものではない。
- ネイティブ市場データで注文拒否、長時間pending、部分決済、注文番号の遅延確定は未観測。純粋な状態ハーネスの拒否/部分残の試験と、実ブローカーの約定経路の証明を混同しない。
- Model4指定でもA/Bともに `no real ticks, every tick generation used`。全期間が生成ティックで、リアルティック検証済みとはしない。2026ホールドアウトの評価、デモ・ライブ昇格は行っていない。

比較原本：[A OFF/ON](a/20261021_235245_00512912/)、[B OFF/ON](b/20261021_235636_802a6036/)。原計画は[固定比較計画](../../../knowledge/experiments/2026-10-21-wave33-opposite-exit-plan.md)、変更の説明は[devlog](../../../docs/devlog/2026-10-22-wave33-opposite-profit-exit.md)。
