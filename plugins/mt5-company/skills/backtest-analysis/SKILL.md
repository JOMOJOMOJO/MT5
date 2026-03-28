---
name: backtest-analysis
description: MT5 のテスター結果、最適化結果、負けパターンを分析して、次の EA 改善や検証実験へ落とし込む skill。レポートを見て原因を詰めたいときに使う。
---

# Backtest Analysis

感想ではなく、次の実装や検証アクションへ変換するための skill です。

## あると良い入力

- MT5 テスターの HTML, XML, CSV
- 最適化結果の要約
- エクイティカーブ、ドローダウン、トレードログ
- シンボル、時間足、スプレッド、手数料前提

可能なら先に MT5 MCP の `import_backtest_report` で `reports/backtest/runs/` へ取り込んでから分析します。

## 分析順序

1. 標本数と取引回数
2. Profit Factor, 期待値, Drawdown
3. 買いと売りの偏り
4. セッションや相場局面への依存
5. スプレッド、手数料、スリッページ感応度
6. 近傍パラメータでの安定性
7. カーブフィット臭の有無

## 出力ルール

- まず何が壊れているかを先に書きます。
- シグナルの問題と執行/コストの問題を分けます。
- 大改造ではなく、次に試す少数の実験へ落とします。
- 使い捨てにしたくない結論は `knowledge/backtests/` や `knowledge/lessons/` に残します。
- 共有判断にすべき内容は `.company/qa/` にも反映します。
- run 同士の差分確認が必要なら `compare_backtest_runs` を使います。

## 参照

- 指標ガイド: `references/metrics.md`
