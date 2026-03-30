# Backtest Reports

`reports/backtest/` は固定パラメータの single test を扱う。

## フォルダ

- `imported/`: MT5 から出た HTML, XML, CSV レポートのコピー
- `runs/`: 機械可読な run JSON
- `comparisons/`: baseline と candidate の比較メモ

## 使い分け

- 短期の parameter search は `reports/optimization/`
- 候補を固定した single test は `reports/backtest/`
- out-of-sample も single test として残す

## 基本フロー

1. `reports/presets/*.set` に固定パラメータ preset を置く
2. `reports/backtest/*.ini` に `PresetSource=` を書く
3. MT5 で single test を回す
4. `python plugins/mt5-company/scripts/mt5_backtest_tools.py import --report <path>` で取り込む
5. `reports/backtest/runs/` を比較する
6. 学びを `knowledge/backtests/`, `knowledge/lessons/`, `knowledge/patterns/` に残す
