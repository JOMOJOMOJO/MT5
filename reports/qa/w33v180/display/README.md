# v1.80の描画確認

表示変更は売買判定を変更しない。MT5の実行とコンパイルは親タスクが管理する専用端末で行う。

- 接続する逆①候補による取消は、逆候補が既知になった日時に赤い点と1本分の有限ガイドを置き、「見送り: 接続する逆①候補」と表示する。古い共有スイングへ判断線を遡らせない。ツールチップを分け、取消の原因候補ID・その既知日時・共有スイング日時と価格を追跡できるようにする。
- 最終TPがRRだけで計算したTPより伸び、既知の①終点を根拠とする場合だけ「TP ①手前」と表示する。緑線のツールチップには最終TP・実際のRR・RRだけの元TP、ラベルには①終点の位置日時・既知日時・余裕ポイントを記録する。抵抗によるCAP等で延長が採用されなかった場合は従来の「TP」を表示する。
- 補助イベント `TP_WAVE1_EXTENDED` 単体ではENTRYやTP線を作成せず、すでに作成したTP線を移動しない。実行判断で確定した `SIGNAL` のTP値を維持し、約定後の線は終了日時までの有限線にする。
- 固定パネルは追加しない。従来どおり初期設定は表示なし。既存CSVに新列がなくても、描画リプレイは従来表示のまま読める。

`Wave33DisplayHarness` にLONG/SHORT計32項目を追加した。新候補が既知になる前の非表示、取消後の線停止、未来sourceの不採用、TP延長の向き、非延長時のラベル互換、診断イベントが元のTP線を変えないことを確認する。非ビジュアルテスターでTOOLTIP読戻しができない場合、その4項目はUNAVAILABLEとし、通常チャートのオブジェクト一覧で別途確認する。

`prepare_review.py` は、新しいネイティブ `events.csv` から「接続取消」「TP延長」のLONG/SHORTをそれぞれ最初の1件ずつ抽出する。合計最大4件であり、不足した分類は `shortfall` に残す。元のイベント行順と終了行を固定し、同秒の後続イベントも先に見せない。CSVの売買判断を書き換えたり、存在しない事例を生成したりしない。

```powershell
python reports/qa/w33v180/display/prepare_review.py --run <native-run-A> --run <native-run-B> --out reports/qa/w33v180/display/native
```

出力 `fixture.csv` は `Wave33DrawingReplay` で読む。各事例の終了時刻より前に確定したM1のみに限定した専用カスタム銘柄で描画し、PNG・`caseN_objects.csv`・コンパイルログを同じ証拠フォルダーへ保存する。これは売買コードを持たない通常チャートの記録再生であり、MT5ビジュアルテスターから直接撮った画像とは区別する。

`audit_review.py --dir <描画フォルダー>` は、元のイベントファイルのSHA256と同秒の終了行、未来情報を含まない抽出、有限線、固定パネルなし、最終TP値、元RRのTP、①の既知日時、接続取消の原因IDと共有スイングの完全なTOOLTIPをオブジェクト一覧で照合する。

## 検証状態

表示ソース・Replay・DisplayHarnessの差分検査はエラーなし。Python構文確認済。初回batchと最終 `final/20261023_150705_4035cece/display_harness/harness.csv` で **101 PASS / 0 FAIL / 10 UNAVAILABLE** を確認した。今回の追加分は28 PASS / 4 TOOLTIP UNAVAILABLE。新列のないv1.71 CSVでは新分類0件・4分類不足となり、過去の事例を新機能成立例として誤認しないことも確認した。

通常チャート記録再生は[final](final/provenance.json)で完了した。取消LONG/SHORT・TP延長LONG/SHORTの4事例を取得し、不足は0。[オブジェクト監査](final/drawing_audit.json)は**1,775 checks / 0 failures**、PNG・全TOOLTIPを読戻して確認した。非ビジュアルハーネスのUNAVAILABLEは、その実行環境で読めなかったことを示す履歴として残す。通常チャートの実オブジェクトでは新しい根拠TOOLTIPの全文・最終TP・有限ガイドを確認できた。

根拠fixtureはBOMなしUTF-8。新設オブジェクト名は`opposite_cancel_known` / `opposite_cancel_leader`とし、実EAのprefixを含めてもMT5の63文字上限を超えない。初回の問題と最終再コンパイルの経緯は[修正記録](../audit_corrections.md)。売買エンジン・元イベントは変えていない。
