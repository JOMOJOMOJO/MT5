# Optimization Reports

`reports/optimization/` は MT5 の parameter search を扱う。

この repo の基本方針は次の通り。

- Optimization は短い探索 window で使う
- 探索で見つけた候補は固定して `reports/backtest/` で再検証する
- 探索結果そのものの判断と採用理由は `knowledge/optimizations/` に残す

## 推奨フロー

1. `research-director` で search window と対象 input を決める
2. `reports/presets/*.set` に search preset を置く
3. `reports/optimization/*.ini` に `PresetSource=` を書く
4. MT5 の optimization で短期探索を回す
5. 良かった pass を XML または保存済み設定として残す
6. 候補の set を固定して長期 validation を single test で回す
7. さらに明示的な out-of-sample window を single test で回す

## 運用メモ

- Optimization は 1 週から 1 か月程度の探索に使う
- 最適化する input は少数に絞る
- 1 年検証は optimization の代わりではなく、固定パラメータ validation の役割
- MT5 built-in forward を使う場合でも、repo には single test の OOS 結果を残す
