---
name: statistical-edge-research
description: MT5 の bar data を掘って、時間帯・ボラ・レジーム・価格乖離から統計的な偏りを見つけ、EA に落とせる候補へ変換する skill。
---

# Statistical Edge Research

この skill は「先にチャートや時系列を分析して、期待値の偏りを見つけてから EA を作る」ために使う。

## 使う場面

- 既存 EA の tuning だけでは改善が鈍い
- まず市場の偏りを見つけてからロジック化したい
- 時間帯、レジーム、距離、RSI、ATR などの条件で期待値が偏るか調べたい
- 5 回/日以上のような trade frequency 条件を先に満たす候補がほしい

## 手順

1. `plugins/mt5-company/scripts/statistical_edge_research.py` で MT5 から bar data を取得する
2. session / side / feature bucket ごとの expectancy を比較する
3. train と test の両方で残る候補だけを候補群に残す
4. 候補を `knowledge/experiments/` に要約し、EA prototype に落とす
5. MT5 backtest で再検証し、run を `reports/backtest/runs/` に残す

## 出力で最低限ほしいもの

- どの symbol / timeframe / window を使ったか
- どの feature 条件が効いたか
- trades/day
- train PF / test PF
- 次に EA 化する候補
- 採用しなかった候補と理由

## 注意

- slice を増やしすぎると簡単に data snooping になる
- sample が薄い候補は採用しない
- 期待値が見えても、spread と execution で壊れる候補は落とす
- 統計分析は「発見」用であり、採用判定は必ず MT5 backtest で行う

## 参照

- `references/analysis-checklist.md`
