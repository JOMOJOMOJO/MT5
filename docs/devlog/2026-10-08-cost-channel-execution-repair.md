# コスト分析完了と日足検証の実行修正

- [M5コスト分析447取引](../../reports/qa/cost_channel_20261008/runs/20261008_103353_57f61562/cost_review/summary.md)：元売買との完全一致を確認。LONGのmid値動きの大部分がspread負担で相殺、SHORTはmid値動き自体も負。
- [日足修正・再実行仕様](../../reports/qa/cost_channel_20261008_r2/plan.md)：休場拒否後のシグナル消費と、MT5更新時のPID交代追跡を修正。初版日足のQA合格を取り消した。
- 日足の設定・期間は固定。修正版EA0 errors / 0 warnings、Python16テスト、PowerShell構文検査合格。本番EA・Shared・既存dirtyファイルは維持。
- 完了済みM5の4本はhash固定で再利用。日足3本だけを独立MT5で実行し、起動後のポーリングはしない。
- [再利用できる教訓](../../knowledge/lessons/mt5-signal-preservation-and-report-completion.md)：取引が一件出ただけではシグナル処理の完全性は確認できない。

利益を得るための設定緩和や追加最適化は行っていない。日足戦略の継続・棄却判断は、有効な固定期間の実行結果が揃うまで保留。
