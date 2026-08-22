# 急変シグナルはエントリー前のコスト条件で消える

相場パターンが見つかったことと、そのパターンを実行可能なリスク幅で売買できることは別問題である。

6通貨・2025年3月のtick-shock研究では、5,962のraw candidateから7イベント、4 pullback、2 reaccelerationへ到達した。しかし`risk >= 5*spread`と`risk <= 0.45*burst`を同時に満たすbarrierがなく、54条件×イベントの実行損益sampleは0件だった。

これは「負けた」のではない。損益分布をまだ観測できていない。ここで`NO_EDGE`と結論づけたり、件数を増やすために検出閾値を緩めたりすると、検出器とexecution geometryの不整合を隠してしまう。

研究の順番は、signal frequency、execution feasibility、cost後outcomeを分離する。特に`Move/Spread`の検出下限と、spreadに対する最小stop、burstに対する最大stopは、バックテスト前に同時成立範囲を数式で確認する価値がある。

Evidence: [internal verdict](../../knowledge/experiments/2026-08-21-multicurrency-tick-shock-scalper-baseline.md), [v4 final run](../../reports/backtest/runs/20260821_tickshock_research_v4_final/summary.md).
