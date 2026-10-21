# 20件生成監査

2026-10-02。最終判定：**20/20 PASS（raw20枚・annotated20枚）**。
要求された時刻・入力分離・画素不変性・公開物監査の範囲で未来情報混入を検出しなかった。これは将来の予測力や保存元データの全ての問題がないことを証明するものではない。

## 実施結果

| 検査 | 結果 |
| --- | --- |
| 固定母集団／抽出 | 2083件から2016〜2025各年20件、計200件 |
| 試作 | 各年の抽出順位1・2、計20件。年ごとの入れ替えなし |
| 再抽出再現性 | 保存集合と固定seed再計算が一致 |
| 重複 | candidate_id、blind_idとも0 |
| 表示OHLC | 6560足、全てclose_time<=Entry・available_at<=Entry |
| prefixだけで描画 | 20件×2版でpixel hash完全一致 |
| 未来・未取得OHLCを極端値へ改変 | 20件×2版でpixel hash完全一致 |
| outcome/R/TP/SL/exit/MFE/MAE改変 | 20件×2版でpixel hash完全一致 |
| 描画注釈 | 189点、全てbar/confirmed/available<=Entry |
| CHoCH | M1/M5の40点全てCSV・足・終値breakと照合 |
| 未来confirmed timeの注釈 | 全20件で描画されないことを確認 |
| READY境界 | 4パネルとも固定右境界。未確定足を追加しない |
| 原ログ照合 | 20件の描画用構造列とEntry quoteが一致 |
| raw/annotated共通ベース | overlay外の全画素が一致 |
| PNG | 40枚全て2400×1600 RGB、info空、IHDR/IDAT/IENDのみ |
| 公開物 | 40PNGと別置き3列manifestのみ。年・候補ID・時刻・出典・結果・private pathなし |
| 本番コード | EA/Shared/収集コードの作業前後hash不変 |

## 見つけて修正した点

CHoCHの内部構造はbar timeを持つが、CSV書き出しはTF秒を加えた**閉じた時刻**だった。試作初回はこれを開始時刻と扱ったため11点で終値照合が失敗した。EAの `CSVSignal` 書き出しを確認し、CSV時刻をconfirmed time、そのTF秒前をbar timeとして修正した。

修正後は全40 CHoCH点が照合合格。20件のraw pixel hashは初回と完全一致。再抽出・成績閲覧・表示倍率変更はせず、同じ候補のannotatedを再生成し、全監査を再実行した。初回監査は `private_audit/pre_choch_timestamp_fix/` に保存。

## 省略した注釈

return highは9件で元ログに存在し、検証して描画した。残る11件は元ログに存在しないため省略した。未来点や仮の高値で補完していない。最終版に価格・時刻不一致を抱えた注釈はない。

## ラベル分離

母表を列許可リストで読むため、結果ラベルやTP/SLの価格は描画用データとして読み込まない。画像rendererは相対OHLCと検証済み表示点だけを受け取る。ランダム改変テストもこの投影境界の前で実施した。

`private_label_manifest_20.csv` は候補対応・時刻・年・品質等の管理情報だけで、実現損益・TP/SL結果もChatGPT判定結果もまだ含まない。publicに渡すファイルはPNGと公開3列manifestのみ。管理・監査ファイルを一緒に添付しない。

## 証跡

- [足時刻](private_audit/ohlc_availability.csv)
- [注釈時刻](private_audit/annotation_availability.csv)
- [全件の画素監査](private_audit/pixel_audit.csv)
- [最終画像hash](private_audit/final_image_hashes.csv)
- [出典・本番ファイルhash](private_audit/machine_audit.json)
- [画像QA](image_qa_20.md)

固定200件manifest SHA256：`deffe4262d9252d6ffe7f2a96e64d7c7e4d8736962a973a3e4847f6f5d352ec5`。

## 停止状態

残り180件は未生成。採点、結果join、TP/SL比較、LightGBM比較、新特徴量追加、EA変更は未実施。追加180件にも同じ監査を全件適用する前提で、rawの生成実装は拡張可能と判断する。annotatedは今回20件の比較用に限る。
