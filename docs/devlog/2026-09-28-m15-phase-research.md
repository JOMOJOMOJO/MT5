# M15フェーズ研究：固定候補の文脈と利確比較

直近設定をM5に固定するユーザー回答に従い、現行EA/Sharedを変更せず研究専用EA・凍結Includeを追加。M15確定pivotと終値breakの状態機械、同一Entry/SLのRR1/1.2/1.5/2、H1/H4抵抗特徴、1ポジション・15分クールタイムの実行台帳を実装した。

コンパイル0/0。既知2025年上期80候補、別期間2024年Q3 39候補。独立Pythonの因果再生とnativeの全状態が一致し、再実行5CSVも一致。本番hash不変。

結果は [summary.md](../../reports/qa/three_wave/m15_phase_research/summary.md)。Wave3は合計1件、Wave1は5件で利確の使い分けを判断できない。実行回数は月6〜17回で頻度目標未達。2024年Q3は生成ティックへの置換が多く、厳密な実ティックOOS扱いを拒否した。フィルター・閾値探索・本番反映なし。

QAでM15構造否定をヒゲから終値へ揃えて本集計前に固定し、旧試作結果を除外。証拠は [修正記録](../../reports/qa/three_wave/m15_phase_research/qa_correction.md)、[再現性](../../reports/qa/three_wave/m15_phase_research/reproducibility.json)、[hash](../../reports/qa/three_wave/m15_phase_research/final_hash_verification.json)。

停滞評価：現候補集合への追加フィルターでは月20回を達成できない。候補集合を変える場合は別実験とし、先にティック品質と状態別標本数を確認する。外部向けには未熟な少数標本のため記事seedは作成しない。
