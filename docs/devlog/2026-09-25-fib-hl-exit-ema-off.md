# Fib/HL保護更新研究のEMA条件をOFF

ユーザーの指定により `InpUseEMAFilter=false` で同一の2025Q1を再比較。これはEMA20>50>100および3本上向きのゲートを無効にする。EMA表示は独立してONにできる。平行な傾きの一致を要求する実装ではない。

研究EA、売買用EA、Shared、既存のリスク・発注処理を変更せず、専用EMAOffプリセット2個を追加。既存ON結果とプリセットは保存した。分析スクリプトには入力run-prefixと出力フォルダを指定する引数だけを追加し、比較結果を別フォルダに保存できるようにした。

[固定計画](../../reports/qa/three_wave/fib_hl_exit_noema/plan.md)、[結果](../../reports/qa/three_wave/fib_hl_exit_noema/summary.md)、[ソース・バイナリ一致監査](../../reports/qa/three_wave/fib_hl_exit_noema/source_audit.json)。新たな最適化・売買用への昇格は行っていない。
