# Entry/SL固定でRR選択を学習する研究を準備

ユーザーの目的は「方向は合っていたが1.2Rが遠かったか」の直接検証。前回の固定RR1.2ラベルを流用するだけでは答えられないため、同じEntry/SLに対してRR1の反実仮想を追加した。

M1の両バリア到達をRR1/1.2の和集合で除外し、5件＋未完了4件を分離、2082件で比較。うち81件が1R勝ち/1.2R負け。固定RRを1へ下げても、他の勝ちの利幅縮小と相殺され全体平均はほぼ同じだった。Entry情報で81件を識別できるかを5パターンで調べる。

時刻/spreadを明示入力から削除、tsfresh固定抽出、波形PCA/logistic、tsaug学習側ノイズを追加。過去のみ較正・年次評価・固定期待R選択。売買EA/Shared変更なし。専用venvを用意し、全モデルの小規模fit/predict、バリア判定、特徴量allowlistと因果時刻を確認した。

[固定計画](../../reports/qa/three_wave/ready_rr_choice/plan.md) / [準備QA](../../reports/qa/three_wave/ready_rr_choice/prelaunch_qa.json) / [データ監査](../../reports/qa/three_wave/ready_rr_choice/dataset_audit.json)

学習はバックグラウンド実行。完了後、ユーザーの連絡を受けて年別結果・選択バイアス・頻度・グラフをレビューする。記事seedは結果判明後に必要性を判断する。
