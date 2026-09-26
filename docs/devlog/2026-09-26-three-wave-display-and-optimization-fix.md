# 終値ピボット描画・理由ログ・最適化準備の修正

ユーザーは複数通貨の利用を明示。USDJPY限定ガードは復元しない。

## 変更

- EA v1.05、Shared indicator v1.08。
- 上位Closeピボットは親足の終了境界へ描画。価格、bar_time、confirmed_time、売買SLを変更しない。ヒゲモードは従来の極値時刻。
- 親/下位TFの表示名を入力に追従。Close/Wickを明記し、ツールチップへplot時刻追加。
- SkipHL時のCSV/Experts理由はSKIP_HL_CHOCH_ONLY。チャート候補表示もCHoCH only。
- OnTesterInitでエントリー方式・SkipHL・EMA ON/OFF・下位TFを現在選択値に固定して、方式ごとに探索する。未対応Fib/CloseBreak組合せは開始前に説明して停止。非稼働パラメータの探索を除外し、RETEST近接幅を(0,1]へ制限。EMA有効時は3期間の範囲が交差したら開始前に停止する。
- READYで使わないHLNearFractionの数値によるOnInit拒否を撤去。RETEST+SkipHLは説明付き拒否。
- 元の設定値を保ち、上位TFと左右ピボット本数4項目だけ探索するプリセット追加。

## 証拠・利用

- [修正前原本と差分・コンパイルログ](../../reports/qa/three_wave/display_optimizer_fix_20260926/)
- [安全な探索用set](../../reports/qa/three_wave/display_optimizer_fix_20260926/M1_M4_selected_safe_optimization.set)
- [元の監査](../../reports/qa/three_wave/m4_review_20260926/summary.md)
- [新仮説の数学的定義案](../../knowledge/experiments/2026-09-26-first-pullback-lower-reversal-spec.md)

EAとSharedのコンパイル0エラー/0警告を確認。今回、最適化実行・半年再バックテスト・新仮説の期待値評価は行っていない。最適化フックの実行時ログ確認は未実施。選択中の有効な設定でのエントリー・SL・TP算出を変える修正ではない。

新仮説は、親HLの確定待ちと『起点未割れの押し候補』を分け、候補時刻と確定時刻を保存して入口遅延を測る研究仕様として残した。売買条件には未追加。

コンパイルは標準scripts/compile.ps1が全ターミナルへEX5を同期するため、今回の対象だけを更新する目的でMetaEditorを直接Hidden起動した。インジケーターの配置先ソースはrepo側Includeを参照するようにし、古いMQL5/Includeの別コピーは上書きしない。
