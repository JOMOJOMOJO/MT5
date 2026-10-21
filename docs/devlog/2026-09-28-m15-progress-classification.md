# M15進行状態の再分類

前回の119候補・476 RR結果を固定し、研究用PythonでM15進行状態を追加した。売買用EA/Shared/Entry/SL/TPは変更していない。事前仕様は [plan.md](../../reports/qa/three_wave/m15_progress_research/plan.md)、結果は [summary.md](../../reports/qa/three_wave/m15_progress_research/summary.md)。

旧DOWN28件のうち120分以内H0終値突破は14件。旧DOWN内でDOWN_WEAKENINGは9/15、DOWN_CONTINUINGは5/11だが、期間別の順位は逆転する。転換初動の混在と、事前に識別できることを分けて報告した。

新W3_CANDIDATE11件、UNKNOWNは76から54件へ。ただし押し開始から中央値200分経過し、全てを初動直近とは呼べない。W3_CONFIRMEDも長く継続するため旧DOWN2件と重なる。結果を見て時間閾値やEMA条件を追加せず、経過時間を診断列として残した。

候補・Entry/SL/TP/損益の一致、元CSVhash、未来改変・途中切断による過去不変、旧H0復元とnativeの一致373イベントを確認。新規MT5実行ではなく前回MT5出力の再分析。2024年Q3の生成ティック制約は継承。

採用なし。前回から頻度も増えず、月20回要件は未達のまま。記事seedは小標本のため作成しない。
