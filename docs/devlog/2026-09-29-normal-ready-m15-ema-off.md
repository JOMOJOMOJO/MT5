# 通常READY・EMA OFFの分離検証を準備

前回EMA ON研究に対し、売買条件の差分をEMA OFFだけに固定。全READY shadowと実注文リプレイを研究専用で並行記録する。売買EA・Shared本体は編集しない。

研究EAはコンパイル0 errors / 0 warnings。短期売買一致、既知2期間、再現性再実行の順でローカルキューを構成した。ユーザー指定に従い、MT5起動後は対話ターンを終了し、次回声掛けまで結果集計をしない。実行完了・検査合格は起動前には主張しない。

[固定仕様・実行状態の場所](../../reports/qa/three_wave/m15_normal_ready_ema_off/plan.md)

## 完了・結果集計

ユーザーの再開依頼後に保存済み結果を集計した。追加のMT5起動は行っていない。短期本体一致・半年再実行・139候補ID一致・入力差分EMAのみ・因果時刻・M15独立計算一致の検査は全て通過。

全READY shadow139候補（138確定）は−0.148R、PF0.763。実行可能リプレイ132件は−0.155R、PF0.756。ON版70件から件数は増えたが期待値は改善しなかった。月平均14.7件、月20以上は1/9か月。DOWN_HIGHの合算正は8件かつ期間別で逆転し、採用根拠にしない。

[結果と全CSV](../../reports/qa/three_wave/m15_normal_ready_ema_off/summary.md)／[再利用する知見](../../knowledge/experiments/normal-ready-ema-off-20260929.md)
