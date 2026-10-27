# 第1波延長 v1.70 最終描画レビュー

対象: 最終ネイティブ実行 `final/20261022_140527_f4364f5c` のA/B各5件。Aは描画担当がPNG5枚を直接確認、Bは主担当がPNG5枚を直接確認した。旧版A画像は最終判定に使わない。

**オブジェクト監査: 8,761チェック、違反0。描画の判定: 履歴整合はPASS、文字の近接・重なりは下記の制約として残る。**

画像は記録済みイベントと終了時点までに確定した実際のM1履歴を、通常チャート上で描画したもの。MT5ビジュアルテスターからの直接キャプチャではない。再計算・発注はしていない。

元CSVとの値・行順・終了時刻、最後の対象snapshot、全revisionの旧灰色/現行青色、旧Fibの終了時刻、新Fibの確定時刻開始、W2のアンカー、TOOLTIPの確定日時、無限レイ・固定パネルなしを機械照合した。文字の重なりはPNGの目視確認で記録した。

| ケース | 分類・画像 | 目視所見 |
|---|---|---|
| A M15×M5 #0 | EXTENDED_LONG_SIGNAL / [PNG](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/qa/w33ext/imgAf/W33R_9C74EA6B9B90B1CD_0.png) | 青①はr2、旧r0/r1は灰色破線・旧終点、現行②とFibはオレンジ。ENTRY/SL/TPと①高値まで1.07Rを確認。旧ラベルが左下で一部近接し、ENTRY付近の紫の抵抗候補文字にも重なりがある。 |
| A M15×M5 #1 | EXTENDED_SHORT_SIGNAL / [PNG](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/qa/w33ext/imgAf/W33R_9B74E8D85B058D50_1.png) | 売り側の旧r0と新r1を区別できる。関連する上昇①も履歴に含み、逆①の黄色い待機・利益決済が見える。ENTRY・EXIT・抵抗候補の文字は約定付近で一部重なる。 |
| A M15×M5 #2 | EXTENDED_TERMINAL_NO_SIGNAL / [PNG](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/qa/w33ext/imgAf/W33R_9E74ED91E9BA8D87_2.png) | 8回延長した全旧①・旧②・旧Fibが灰色で残り、現行r8の青①を識別できる。初期の旧ラベル群が密集し、最終②と時間切れSKIPの文字が重なる。未成立例の履歴と終了は追跡可能。 |
| A M15×M5 #3 | MULTIPLE_REVISIONS / [PNG](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/qa/w33ext/imgAf/W33R_9D74EBFEFC3C43AA_3.png) | 売り側4回延長の旧終点r0〜r3、現行青r4、現行オレンジ②とENTRY/SL/TPを確認。旧②r2/r3の文字が一部近接するが、現行波は区別できる。通常SL/TP終了に専用の大きなEXIT文字は出ない既存仕様。 |
| A M15×M5 #4 | UNEXTENDED_FIB_LOCKED_CONTROL / [PNG](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/qa/w33ext/imgAf/W33R_A074F0B7E6B32609_4.png) | 非延長r0の対照。青①・オレンジ②/Fib、M15終値62.9%での見送りの赤い観測点・有限リーダーが明瞭。旧延長の不要な線・固定パネルなし。 |
| B M5×M1 #0 | EXTENDED_LONG_SIGNAL / [PNG](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/qa/w33ext/imgB/W33R_D25CF11BBBB03F7D_0.png) | 主担当が目視確認。旧r0は灰色、新r1は青、現行②/Fibはオレンジで区別できる。ENTRY/SL/TPを確認。 |
| B M5×M1 #1 | EXTENDED_SHORT_SIGNAL / [PNG](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/qa/w33ext/imgB/W33R_D15CEF88411B3BC8_1.png) | 主担当が目視確認。約定後29秒でSLへ到達したためSL/TPは右端の短い有限マーカー。通常SLには専用の大きなEXIT表示がない既存仕様で、終了理由・実時刻はCSVで確認する。 |
| B M5×M1 #2 | EXTENDED_TERMINAL_NO_SIGNAL / [PNG](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/qa/w33ext/imgB/W33R_D45CF4410820E747_2.png) | 主担当が目視確認。旧①と延長①、未成立SKIPを区別できる。オレンジ②と赤いSKIPの文字に軽微な重なり。 |
| B M5×M1 #3 | MULTIPLE_REVISIONS / [PNG](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/qa/w33ext/imgB/W33R_D35CF2AEBFB3A912_3.png) | 主担当が目視確認。7回延長した旧ラベルが密集するが、現行青r7とオレンジ②を識別できる。旧終点の細部はオブジェクトのTOOLTIP/CSVを併用する。 |
| B M5×M1 #4 | UNEXTENDED_FIB_LOCKED_CONTROL / [PNG](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/qa/w33ext/imgB/W33R_D65CF767073215E9_4.png) | 主担当が目視確認。非延長対照の通常描画。青①、オレンジ②、ENTRY/SL/TPに異常なし。 |

## 残る表示上の制約

多数の延長を同一画面へ残すと旧ラベルが密集する。今回のA#2（8回）・B#3（7回）は履歴を削除せず残したため、この制約を明示する。現行①は太い青線、旧①は細い灰色破線で区別できる。

通常SL/TPに大きなEXIT専用マーカーがないのは従来の描画仕様。短時間決済のリスク線には見える長さを確保する最小1本分の表示幅があり、実約定時刻の再定義ではない。秒単位の実終了はevents.csvのEXITを確認する。逆①による利益決済には黄色いEXITがある。

動画の正解波形との一致はこの監査の対象外。画像未提供の箇所を推測で確定しない。今回の成績による選別・描画修正・条件の最適化は行っていない。

[機械監査JSON](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/qa/w33ext/drawing_audit.json) / [Aケース詳細](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/qa/w33ext/imgAf/fixture_cases.md) / [Bケース詳細](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/qa/w33ext/imgB/fixture_cases.md)
