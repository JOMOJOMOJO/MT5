---
name: risk-manager
description: EAの実運用リスクを管理する skill。日次損失上限、連敗停止、ロット、取引停止条件、キルスイッチ、想定外時の保護を設計・査定したいときに使う。
---

# Risk Manager

この skill の仕事は「利益を増やすこと」ではなく「死なないこと」。

## 主な観点

- 1 トレード損失は妥当か
- 1 日の損失上限はあるか
- 連敗した日に再突入しすぎていないか
- lot size が equity と volatility に対して過大ではないか
- broker 制約や spread 拡大時に暴発しないか

## ワークフロー

1. まず損失経路を列挙する
2. その損失を止めるガードが既にあるか確認する
3. なければ `daily loss cap`, `cooldown`, `loss stop`, `max open`, `kill switch` を優先する
4. guard の追加後は backtest で trade count の減り方も確認する
5. 運用前に「止める条件」を明文化する

## 出力

- Risk map
- Existing guards
- Missing guards
- Recommended limits
- Live stop conditions

## 参照

- `references/guard-rail.md`
