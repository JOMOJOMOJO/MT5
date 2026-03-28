# Knowledge Base

このディレクトリは、MT5 EA 開発で得た知見を蓄積するための場所です。

構造化された事実データは `reports/backtest/runs/` に保存し、ここは人が読む判断メモを保存する場所として使います。

## 使い分け

- `backtests/`: バックテスト結果の記録
- `experiments/`: 次に試す仮説や比較案
- `lessons/`: 失敗や発見から得た教訓
- `patterns/`: 再利用できる設計や改善パターン

## 昇格の考え方

- 1 回の結果は `backtests/`
- 次に試す案は `experiments/`
- 再発防止や重要な学びは `lessons/`
- 複数回通用したものは `patterns/`

## 機械可読データとの役割分担

- `reports/backtest/runs/*.json`
  MT5 レポートから取り込んだ機械可読データ。比較や集計の基準にする。
- `knowledge/backtests/*.md`
  その run から何を学んだか、どこが弱かったか、次に何を試すかを書く。

チャットで終わらせず、残す価値があるならここへ保存します。
