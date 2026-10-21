# M5コスト分解と日足基準戦略の研究実装

ユーザーの「実施して」で[提案](2026-10-08-next-research-direction-proposal.md)を研究実装へ進めた。

- [固定仕様・期間・停止条件](../../reports/qa/cost_channel_20261008/plan.md)
- [新しい日足研究EA](../../mql/Experts/Research/DailyChannelPortfolio.mq5)
- [約定quote記録](../../mql/Include/Research/DealQuoteAudit.mqh)
- [パッケージ生成](../../tools/quality12b/prepare_cost_channel.py)
- [監査・コスト分解](../../tools/quality12b/analyze_cost_channel.py)
- [独立MT5 runner](../../scripts/run-cost-channel.ps1)

日足20/10本チャネル、ATR14×2の初期SL、固定TPなし、5銘柄共通条件。リスク0.25%、全保有0.75%、USD同方向0.50%に固定。
M5の既存リスク0.65%等は変更せず、LONG/SHORTの元取引一致を必須にする。
同期quoteが欠けるため既存CSVだけでmid損益を捏造せず、診断専用の再実行を用意した。
同じEntry/Exit時刻の帰属分析であり、無コストSL/TPを再シミュレーションする分析とは区別する。

Pythonテスト10件合格。最終preflight `20261008_103007_d4a53782` の3研究EAは0 errors/0 warnings。
標準compile.ps1は複数端末へEX5同期するため今回は使用せず、独立portable環境内でコンパイルした。
本番EA・Sharedは未変更。既存のdirtyファイルは維持。研究EAはテスター以外で起動できない。

7runを一括実行し、監査不一致なら後続停止。開始時刻とPIDはpackage内last_launch.json、進行状態はruns内status.json。
MT5開始後はユーザーの完了連絡までポーリングしない。利益の結論・本番採用は未実施。
