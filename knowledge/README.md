# Knowledge Base

このリポジトリでは、MT5 の結果を 2 層で管理します。

- 生データに近い事実: `reports/backtest/runs/`
- 再利用する知見: `knowledge/`

`knowledge/` のカテゴリは次の 6 つです。

- `company/`: 組織、skill、MCP、承認フローの改善知識
- `backtests/`: 単発の固定パラメータ検証メモ
- `optimizations/`: パラメータ探索、候補レンジ、採用した設定、捨てた設定
- `experiments/`: 次に試す仮説と変更案
- `lessons/`: 再発防止や重要な学び
- `patterns/`: 複数 EA に流用できる型

## 保存ルール

- 1 回の MT5 単体検証は `reports/backtest/runs/` を真実源にする
- その run から人が読む要約を `knowledge/backtests/` に残す
- 最適化で見つかった候補レンジ、良かった pass、悪かった pass は `knowledge/optimizations/` に残す
- 組織、skill、MCP の snapshot 差分は `.company/improvement/` を真実源にし、再利用できる判断を `knowledge/company/` に残す
- 使い回せる失敗や改善原則は `knowledge/lessons/` または `knowledge/patterns/` に昇格させる

## 使い分け

- 組織変更の判断、skill/MCP の改善履歴を残したい: `company/`
- どの EA、どの通貨、どの期間で起きたかを残したい: `backtests/`
- どのパラメータ探索をしたか、何を候補にしたかを残したい: `optimizations/`
- 次の試行計画を書きたい: `experiments/`
- 今後も守るべきルールを書きたい: `lessons/` または `patterns/`
