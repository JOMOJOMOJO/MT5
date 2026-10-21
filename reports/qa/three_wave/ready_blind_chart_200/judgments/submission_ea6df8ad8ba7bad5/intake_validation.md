# ブラインド判定の受領・固定

提出20件のIDは公開試作20件と完全一致。重複・欠落・未知IDなし。指定7評価項目が全件そろい、5数値項目は全て0〜100。原文と提出順を保存し、評点・commentは変更していない。

| grade | 件数 |
| --- | ---: |
| A | 5 |
| B | 6 |
| C | 9 |

原文SHA256：`ea6df8ad8ba7bad530ff80b80e88ef511c75494beaedca7ca9afd63f5002e141`。

- original_submission.json：添付原文のバイト列をそのまま保存。
- judgments_frozen.csv：後の照合用。blind_idと提出評価のみ。
- receipt.json：受領時刻、原文・公開画像・公開manifest・prompt templateのhash、検証結果。

以前の案内によりraw判定を想定するが、実際に使用した画像版、モデル名・版、プロンプト、チャット履歴はこのJSONだけから確認できないため未確認と記録した。添付にない情報を補完しない。

この受領処理はprivate対応表・結果ラベルを読み込まない。実結果join、勝率/損益/PF/AUCの算出、LightGBM比較は未実施。残り180件の画像生成も行っていない。
