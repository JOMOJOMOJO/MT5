# 通常READYブラインド画像：v2・20件試作の固定仕様

2026-10-02。v1の単純無作為200件を、ユーザー指定の年別層化200件へ変更する。今回生成するのは20件のraw/annotated計40枚のみ。残り180件は生成しない。売買EA・Shared・Entry・SL/TPは変更しない。

## 母集団と固定抽出

- 既存 `../ready_generated_tick_ml/all_candidates.csv` の `label_exclusion=INCLUDED` 2083件。
- 各年内でsignal_id昇順に正規化してから、NumPy default_rngの非復元順列先頭20件を採用。各年seedは `2026100200 + year`。TP/SL結果や117特徴での調整・抽出し直しは禁止。
- 各年の抽出順位1・2を試作とする。これをseed=2026100291でシャッフルし、200件manifestの先頭20行に置く。残り180件も同乱数系列でシャッフルする。画像生成順は独立seed=2026100292。
- blind_idは時刻を含まないUUIDv4の32桁文字列。最初の生成時に保存し、再実行では対応表を読み、抽出候補・順番・seedの完全一致を検証する。IDを振り直さない。
- `blind_sample_manifest_200_private.csv` が本番候補集合の正本。private_audit/machine_audit.jsonへファイルhashを保存する。
- 年別20件のため、全候補の年別構成比そのものではない。後の主集計は年均等標本として明記し、母集団比率の推定は別途年別重みを使う。今回は採点・損益集計をしない。

## 入力と描画の境界

- Pythonで保存済みOHLCを描く。MT5の再起動・再テストは不要。
- 母表読み込みは列許可リスト。描画用にoutcome、実損益、TP/SL、exit、MFE/MAEを読み込まない。抽出用の既存品質除外フラグは管理側だけで使用する。
- 次に構造・足の時刻を監査し、`Scene`へ変換する。rendererが受け取るのはblind_id・TF名・相対OHLC・表示座標に変換された検証済み注釈のみ。candidate_id、年、絶対時刻、絶対価格、private pathはrendererに渡らない。
- 切断は実Entryのミリ秒時刻。各足のclose_time<=Entryかつavailable_at<=Entryを必須とする。形成中足を描かない。
- 1枚2400×1600、2×2：M1 120本／M5 96本／M15 64本／H1 48本。横軸は確定足順序、右境界=判定時点。足間の実時間空白は圧縮し、形成中上位足の途中形状は含まれない。
- USDJPYの1pip=0.01。縦軸はEntry時Bid=0の相対pips。Bid/Ask二重線・Entry線を描かない。
- y範囲は各パネルの表示足low〜high＋上下5%（最小余白0.2pip）。注釈・SL/TP・結果で範囲を変えない。画面上の角度は価格速度の絶対比較には使えない。
- rawはローソク、グリッド、相対軸、TF、本数、blind_id、境界説明のみ。pivot、CHoCH、Wave1/2、READY、Entry価格線なし。

## annotated

- raw画像を共通ベースにし、透明overlayだけ追加する。余白・軸範囲・ローソク位置・大きさは完全共通。
- M5 origin/broken high/Wave1、M1 reversal/broken high/Wave1/HL/return high、M1/M5 CHoCH、READY境界を候補とする。M15/H1に新しい構造推定を加えない。
- 元の `TW_signals.csv` と母表の全描画用構造列を照合する。実Entry時刻・Bidはquotesと照合する。
- pivotはヒゲLeft2/Right2、Sharedと同じ左側厳密・右側同値許容。候補価格、左右5足、理論confirmed time、全確認足のavailable_atを検査。
- CHoCHの内部構造はbreak足の開始時刻だが、`TW_signals.csv` の書き出しはTF秒を加えた閉じた時刻。CSV時刻をconfirmed time、そのTF秒前をbar timeとして照合する。閉じた足が既知のbroken highを終値で上抜いたこと、broken high自身の確認も必要。時刻の定義はEAのCSV書き出し部分で確認した。
- 固定表示窓外、ログ欠損、価格／時刻検証不一致は描かずprivate_audit/annotation_omissions.csvに残す。表示範囲を広げたり未来のpivotで補完しない。
- 注釈は上部専用余白の色付き凡例と小さな中抜きマーカー。ローソク本体を全面的に塗りつぶさない。

## 監査

20件×raw/annotatedすべてについて以下を実施する。

1. 全表示足、全表示注釈の時刻監査。
2. Tで切ったprefixだけを入力した画像とpixel hash完全一致。
3. T以後またはT時点未取得のOHLCを極端値へ改変して再描画しpixel hash完全一致。
4. outcome/R/TP/SL/exit/MFE/MAEと実列名の別名を乱数へ変更しても、許可リスト投影とpixel hashが完全一致。
5. 注釈のconfirmed timeを未来へ変えると描画されない負例テスト。
6. PNGはPillowによるRGB画像のみ。IHDR/IDAT/IEND以外のchunk禁止。PNG info空。全ファイル名は保存blind_idのみ。
7. 公開ディレクトリは40PNGのみ。公開manifestは3列のみ。可視文字列も監査する。ファイルの更新・アクセス時刻は統一する。作成時刻はデータのEntry時刻と関連しない生成時刻であり、画像内には保存しない。
8. raw/annotatedの透明overlay外の全画素が同じであることを検証。注釈が重なるローソク画素割合を記録。
9. 200/20の年別件数、候補とIDの重複0、保存集合と再計算集合の一致、EA/Sharedの作業前後hash一致。

## ファイル分離

- public/raw/<blind_id>.png
- public/annotated/<blind_id>.png
- public_sample_manifest_20.csv：blind_id,raw_image_path,annotated_image_pathのみ。
- blind_sample_manifest_200_private.csv：固定抽出・時刻・年・出典・品質・対応。
- private_label_manifest_20.csv：試作の管理対応のみ。今回、実現outcome/R/TP/SLやChatGPTの評価結果も入れない。将来の結果結合は回答固定後に別処理で行う。
- private_audit/：個別時刻監査、描画hash、欠落理由、出典hash、目視QA用画像。ChatGPTへ渡さない。

ファイル名にprivateと付けただけでアクセス制御があるわけではない。判定にはpublicの画像と中立prompt、公開manifestだけを使い、研究フォルダ全体を添付しない。

## 判定仕様・停止条件

7項目：overall_grade、continuation_probability、wave1_quality、wave2_quality、selling_pressure_decay、higher_tf_alignment、comment。後者は1〜3文。数値は0〜100、gradeはA/B/C。bottoming_quality、structure_cleanliness、timing_qualityは使わない。

主判定はraw。annotated比較を行う場合は別の新規セッションで独立判定し、同じ候補のraw判定やもう片方の画像を見せない。過去の戦略成績・採点済み結果・対応表を見せない。20件は品質QAであり勝敗の採点を今回実施しない。

生成・機械監査・20件の目視QAが完了したら停止。残り180件、評価結果のjoin、TP/SL集計、LightGBM比較、新特徴実装、本番変更は実施しない。判定未実施なら試作20件も固定200件に残る。将来プロンプトの調整用に採点を開封した場合は、その20件を独立検証と混同しない。
