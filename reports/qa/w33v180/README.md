# Wave33 v1.80 — 接続逆①の取消・①手前TP

2026-10-23の依頼に対応。未発注候補を取り消す条件とTP延長を個別にON/OFFできる。既存の約定後の逆①利益決済は維持する。利益最適化・年間再検証は行っていない。

## 実装

- `InpCancelConnectedOpposite=true`：新しい逆①候補の起点が古い確定①終点と同じ日時・価格なら、古い未発注候補をその候補発生時に無効化。送信中・約定済みを保護し、失効した候補は復活させない。
- `InpExtendTPToWave1=true`：LONGは①高値より少し下、SHORTは①安値より少し上へTPを延長。余裕は`max(InpTPWave1BufferPoints（既定10）, spread_points, tick_size/point)`。①の内側へtick丸めし、元から遠いTPは短縮しない。SL・リスク率によるロット計算は維持する。保有中のTP再追跡は行わない。
- RR入力は基本TPの倍率。延長後の実際のRRは別途計算する。明示的な`CAP_TP`は後段で優先する。配布SETは`DISPLAY_ONLY`。
- 新設イベント・CSV列は[計画](../../../knowledge/experiments/2026-10-23-wave33-connected-and-target-plan.md)と[操作手順](../../../docs/validation/wave33-tester-orders.md)を参照。

## 固定ネイティブ検証

XAUUSD+、2023.01.01〜2023.01.10、初期5,000 USD、A=M15/M5、B=M5/M1。RR1・risk1%などは固定。①延長・上位足終値61.8%除外・逆①利益決済はONのまま。新2入力を「両OFF／取消のみ／TPのみ／両ON」の4群にした。[初回19ラン](eng/20261023_112317_3e88623f/review.md)、[8群の独立再計算425項目](native_audit.json)。

| 群 | 候補A/B | 接続取消A/B | TP延長A/B | 約定A/B | EA通常EXIT A/B |
|---|---:|---:|---:|---:|---:|
| 両OFF | 9 / 29 | 0 / 0 | 0 / 0 | 3 / 7 | 3 / 6 |
| 取消のみ | 9 / 29 | 0 / 3 | 0 / 0 | 3 / 7 | 3 / 6 |
| TPのみ | 9 / 29 | 0 / 0 | 0 / 2 | 3 / 7 | 3 / 6 |
| 両ON | 9 / 29 | 0 / 3 | 0 / 2 | 3 / 7 | 3 / 6 |

Bの両ONはLONG取消2・SHORT取消1、TP延長はLONG/SHORT各1。Aに新条件適用例はなく、対称分岐は新ハーネスで確認した。共通SIGNALのSL・risk・基本RR・①アンカーは不変。取消で別候補の順序も変わるため、総取引数が同じでも同じ取引集合とは限らない。Bの期間末1保有はEAのEXIT callback前にテスターが終了するため、自然決済した勝敗へ含めない。

初回の既存・新ハーネス合計は**1,074 PASS / 0 FAIL**。非ビジュアルではDisplayの10項目がUNAVAILABLE（今回追加分4を含む）。Connected120・Target45・OppositeExit91の分岐を確認した。最終ソースを再コンパイルした[8ラン](final/20261023_150705_4035cece/review.md)でも、Display/Connected/Target/OppositeExitとA/Bの両OFF・両ONを確認する。コンパイルログ・ソース/ヘッダーハッシュは各batchに保存する。

旧EX5を[base](base/)に凍結し、専用runtimeで再実行した[旧版native](baseline_native/)と、新2機能OFFの全イベント・足・逆①評価ティックを比較する。[初回一致](frozen_regression.json)、[最終一致](final_frozen_regression.json)。比較コードは[compare_regression.py](compare_regression.py)。新列を除く121イベント列を全行比較し、A785行・B3,195行が一致する。

## 元画像の候補

SHORTの①終点は **2023.01.05 17:35、1825.03**、EAが確定を知った時刻は17:50。その点を起点にするLONG候補が**18:10**に出る。v1.80の取消ONではこの時点で旧SHORTを終了し、旧版の18:25注文は出ない。逆LONGの①終点確定18:30を待たない。ユーザーの対話的テスターの実約定は18:25:07、今回の固定遅延なしテストは18:25:00となるので、約定秒・価格を同一と主張しない。

## 両ONの適用例

| 判定可能時刻 | 対象 | 根拠 | 結果 |
|---|---|---|---|
| 01/04 19:20 | LONG取消 | 18:45高値1860.43を起点に逆SHORT候補 | 未発注終了 |
| 01/05 18:10 | SHORT取消 | 17:35安値1825.03を起点に逆LONG候補 | 未発注終了・18:25旧注文なし |
| 01/06 19:50 | LONG取消 | 19:05高値1864.92を起点に逆SHORT候補 | 未発注終了 |
| 01/06 22:59 | LONG TP延長 | ①終点21:40、既知21:55 | 1868.75→1869.72、予定RR1→1.574 |
| 01/09 20:41 | SHORT TP延長 | ①終点19:35、既知19:50 | 1869.68→1869.15、予定RR1→1.196 |

時刻はすべてブローカー時刻。個別ID・入力・価格は[native_audit.json](native_audit.json)と全イベントへ保存。各パターン5候補の一覧はbatch内の`review_cases.md`を参照する。

既存の逆①利益決済はAで各群1件、同じ市場事例の再実行を確認。最初のREADYティックで要求し、実現純損益は+23.94 USD。B両OFF/TPのみは逆①待機5,727ティック中にプラスがなく要求0、取消ONではその旧未発注候補が先に終了する。4群の反復を独立4取引とは数えない。

## 描画

[最終4事例とオブジェクト監査](display/final/drawing_audit.json)は1,775項目PASS。取消LONG/SHORT・延長TP LONG/SHORTの4分類を実ログから抽出した。元CSVの行順とcutoffを固定し、未来M1を含めない専用カスタム銘柄で記録再生したもの。売買再計算はなく、**ビジュアルテスターを直接撮った画像とは区別する**。左上の固定パネルなし・線の延長なし・根拠tooltip・最終TPを確認した。

- [画像ケースの取消](display/final/W33R_94D11163B006B7AB_1.png)
- [LONG TP①手前](display/final/W33R_95D112F6FA5B34D4_2.png)
- [SHORT TP①手前](display/final/W33R_96D114898C6543A1_3.png)
- [初回監査の修正点](audit_corrections.md)、[表示検証の手順](display/README.md)

## 制約と配置

Model4を指定したが保存区間に実ティックがなく、ネイティブログの`no real ticks, every tick generation used`を確認した。今回のPASSは因果順序と実装の検証であり、実ティックの約定品質や収益改善を保証しない。`CAP_TP`の優先順はコードレビューで確認し、この8群のnativeはDISPLAY_ONLYに限定した。

[配置ハッシュ](deployment.json)のEX5と[v1.80 A](../../presets/wave33-v180-A-M15-M5-orders.set) / [B](../../presets/wave33-v180-B-M5-M1-orders.set)を使用する。ユーザー端末のプロセスは停止・再起動しない。稼働中のEAへ変更が自動反映されるとは扱わず、ユーザーがテスター停止後にEAを選び直して新SETを読み込む。
