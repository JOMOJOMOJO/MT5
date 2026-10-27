# QA中に判明した表示・監査側の問題

売買ロジックの追加変更や成績による設定選別は行っていない。

- 描画用fixtureの初回出力はUTF-8 BOM付きで、MQLのANSI CSV読込が先頭キー`review_index`を認識できず、4事例を0番へまとめていた。既存の描画fixtureと同じBOMなしUTF-8へ修正した。元イベントCSV・判断コードは変更しない。
- 最初の描画監査では、長い描画オブジェクト名がMT5の63文字制限に達し、取消ガイドの末尾が切れた。新設の2オブジェクト接尾辞を`opposite_cancel_known` / `opposite_cancel_leader`へ短縮した。実EAの長いprefixでも63文字以内に収める。修正前の描画は`display/native`、最終再描画は`display/final`へ分離する。
- `independent_target_review.json`当初の8指摘は、延長目標がエントリーの不利益側になる非適用例でも目標値の保存を必須とした監査式によるもの。EAは`TP_W1_TARGET_NOT_PROFITABLE`で基本TPを維持し、未採用目標・余裕は0を記録する。該当した実例はAのSHORT 2023.01.05 14:50（entry1845.20、①安値1845.23）、BのLONG 2023.01.09 15:16（entry1875.89、①高値1875.88）、各2群の4SIGNAL。初期監査をそのまま保管し、最終的な独立再計算は`tools/wave33_visual/audit_connected_target.py`と`native_audit.json`で追跡する。この解消のためEAのTP計算を変更していない。

描画ヘッダーが初回batchのコピー後に更新されたため、最後に現在のソースで再コンパイルし、Display/Connected/Target/OppositeExitハーネス、A/Bの両OFF・両ONを再実行する。初回8群の証拠と、最終バイナリの証拠を混同しない。
