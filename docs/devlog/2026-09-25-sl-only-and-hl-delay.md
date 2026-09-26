# HL確定後SLだけ更新、および入口遅延の分解

ユーザーが初期TPを維持してSLだけ更新する実験を承認。研究EA v1.01に `InpRecalculateTPOnHL` を追加し、falseなら `plan.tp` を保持。既定trueで従来のSL/TP同時更新を維持。EMA OFF・他の入口/リスク/ピボット/クールタイム条件は前回と同一。売買用EAとSharedは変更していない。

コンパイル0エラー0警告。新規SLOnlyプリセットをテスターフォルダにも配置。実験証拠・差分・保護ファイル監査は [fib_hl_sl_only](../../reports/qa/three_wave/fib_hl_sl_only/) に保存。分析スクリプトは別dynamic-runと初期TP不変の監査に対応。

別途、既存READY/HL即時/HL再接近の2025Q1（EMA ON、RR1、M1左右2/2）約定ログからHLの足→確定→決定→実約定を分解。READY23件は中央値4分・最大7分。確定待ち3分に、追加突破待ち中央値1分・最大4分が加わる。HL即時21件は約3分。HL再接近11件は中央値約3.80分。これらは現在の利用者チャートそのものの解析ではなく、保存された比較実験の同じ構造コードの例。

右2のピボットは7:38開始の足なら、候補足自身が7:39に閉じ、右2本が7:41に閉じて利用可能になる。矢印の時刻は候補足の開始時刻。右1にしても確定は7:40である。±1分を目指すなら、現在の厳密な確定HLとは区別した仮HLによる早期反転トリガーが必要。未来にHLになった足を過去の入口として使わない。

その次候補は、reversal lowを維持した押しで、安値候補足が直前M1高値を終値で超えて戻す等の早期反転を記録し、次tickで買う仮説。失敗した候補もすべて残し、後の確定HLとの近さは事後評価だけに使う。今回の出口比較と混ぜて変更しない。

[結果](../../reports/qa/three_wave/fib_hl_sl_only/summary.md)、[遅延CSV](../../reports/qa/three_wave/fib_hl_sl_only/hl_entry_delay.csv)、[遅延集計](../../reports/qa/three_wave/fib_hl_sl_only/hl_entry_delay_summary.json)。
