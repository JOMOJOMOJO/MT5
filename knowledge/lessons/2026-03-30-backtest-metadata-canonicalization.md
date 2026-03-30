# Backtest Metadata Canonicalization

- 日付: 2026-03-30
- 対象: `btcusd_20260124`
- 主題: backtest の証跡を「あとで使える形」に直す

## 何を直したか

- `scripts/backtest.ps1` が report ごとに `.meta.json` を吐くようにした。
- `plugins/mt5-company/scripts/mt5_backtest_tools.py` が sidecar metadata を読み、`signal_timeframe`, `regime_timeframe`, `confirm_timeframe`, `direction_mode`, `preset_name` を run JSON に埋めるようにした。
- `catalog.jsonl` は append-only のままだと誤取り込みが残るので、`rebuild-catalog` で run JSON から再構築できるようにした。

## 学び

- MT5 の tester `Period` は必ずしも戦略の本当の時間足ではない。今回も tester は `M1` だが、戦略の signal timeframe は `H1` だった。
- 過去データを比較に使うなら、`EA / symbol / signal timeframe / direction mode / preset` が追えない run は再利用価値が大きく下がる。
- 生成物の保存先は raw report だけでは足りず、metadata を同時保存しないと後から会社全体の知識に昇格しにくい。

## 今後の運用

- 新規 canonical run は metadata 付きの `H1` 系統を優先して参照する。
- metadata を持たない古い `M1` import は証拠として残すが、比較や集計の主系統からは段階的に外す。
- 大きな sweep や preset 変更の後は `python .\\plugins\\mt5-company\\scripts\\mt5_backtest_tools.py rebuild-catalog` を実行する。
