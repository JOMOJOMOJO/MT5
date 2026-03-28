# Backtest Reports

このディレクトリは MT5 Strategy Tester の成果物を整理するための場所です。

## 役割

- `imported/`
  元の HTML, XML, CSV レポートのコピー。
- `runs/`
  取り込み後の機械可読 JSON。比較や集計の基準。
- `comparisons/`
  run 同士の比較結果を保存する場所。

## 推奨フロー

1. MT5 から HTML や XML のレポートを保存する。
2. `import_backtest_report` か `python plugins/mt5-company/scripts/mt5_backtest_tools.py import --report <path>` で取り込む。
3. `reports/backtest/runs/` の JSON を基準に比較する。
4. 学びは `knowledge/backtests/` や `knowledge/lessons/` に残す。
