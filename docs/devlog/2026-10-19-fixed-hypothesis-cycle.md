# 既存ブレイク応用とRSI2押し目の19条件比較

ユーザーから既存PF>1候補の応用と新しい入口の研究を任されたため、
[計画](../../knowledge/experiments/2026-10-19-hypothesis-cycle-plan.md)を保存してから実装・再生した。
過去のリテスト棄却を踏まえ、今回はブレイク幅0.25ATRの単一除外とRSI2/EMA200の2仮説に限定した。

追加は`tools/entry_research/hypothesis_cycle/`のみ。凍結account_replayを再利用し、既存EA/価格/研究結果を保護。
候補全件台帳、共通暦休止、追加往復1pip、4週対応bootstrap、19仮説Holm、月次MTM、条件付き対照の停止規則を実装。
USDCHF未取得月をNAとし、打切り後の月次損益をゼロで埋めない。

正本：[report.md](../../reports/research/hypothesis_cycle_20261019/validated/report.md)、
[dashboard.html](../../reports/research/hypothesis_cycle_20261019/validated/dashboard.html)、
[QA](../../reports/research/hypothesis_cycle_20261019/qa_validated.json)。
実行方法：[README](../../tools/entry_research/hypothesis_cycle/README.md)。

48テスト合格。142口座シナリオを台帳から照合。代表2条件を完全再現。
初回deliveryと最終validatedの全口座・月次・年次・元候補処理テーブルも完全一致。
最終再生成の変更は打切り明示と全口座打切り時の表示対応で、条件・成績を調整していない。
ブラウザーで月次ヒートマップ・費用感度・応用比較の描画を確認。

PF>1は6/19、月次・頻度ゲート0/19、全採用0/19。7応用の6件で損益改善はあったが、
月次安定性・費用耐性・絶対期待値の区間を同時に満たさない。
詳細な判定とplateau reviewは[研究判断](../../knowledge/experiments/2026-10-19-hypothesis-cycle-verdict.md)に集約。
2026は不使用。Gitの無関係なdirty変更は保持し、commit/pushやMT5発注はしていない。
