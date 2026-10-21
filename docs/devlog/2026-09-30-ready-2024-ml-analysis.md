# 2024通常READY・LightGBMを含む固定モデル比較

## 変更範囲

研究用Pythonのdataset生成・モデル比較・報告コードを追加。売買EA・Shared・Entry・SL/TPは変更しない。収集済み180候補へ194特徴を付与し、M15/H1の2点pivot線位置も記録した。

## 判断と証拠

Model=4でも2024年6月6日以前は実tick履歴がなく、その後40日にも置換警告があった。Entry〜決済に警告がない82件のみを教師ありtargetにした。生成tickを含む98件は消さず、target欠損として保存した。

指定walk-forwardは3区間が学習不足、最後の学習52/検証30件だけ成立。AUCはTree0.658、LightGBM0.557、Logistic0.411。4fold安定性は評価不能。高い予測確率binの少数勝ちを条件採用の根拠にしない。

Wave1 close locationが勝ち側で高い方向は両期間に見られたが、逆行・M15上昇波比は方向が逆転。上位足のグループ置換importanceも支持せず、フィルター採用なし。KMeansは小さな外れ値群を作り、安定した環境分類にならなかった。

## QA

短期observer一致、前研究46候補Entry/SL/TP一致、M15 native180件一致、未来切断5点・改変1点、OOF再実行1e-12以内一致、売買EAと20既存ファイルのhash保持を確認。本ターンMT5追加実行なし。

[summary](../../reports/qa/three_wave/ready_2024_ml/summary.md) / [dataset audit](../../reports/qa/three_wave/ready_2024_ml/dataset_audit.json) / [final audit](../../reports/qa/three_wave/ready_2024_ml/final_audit.json) / [durable lesson](../../knowledge/experiments/ready-2024-ml-20260930.md)
