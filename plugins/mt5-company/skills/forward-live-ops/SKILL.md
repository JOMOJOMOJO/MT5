---
name: forward-live-ops
description: EAをバックテスト段階から demo, forward, live へ段階的に昇格させる skill。監視、昇格条件、ロールバック、実運用チェックリストを整えたいときに使う。
---

# Forward Live Ops

この skill は「完成したか」ではなく「安全に本番へ上げられるか」を扱う。

## ステージ

- backtest only
- demo forward
- small live
- scaled live

## ワークフロー

1. backtest の最低ラインを確認する
2. demo forward の観測項目を決める
3. small live のロットと停止条件を固定する
4. 逸脱時の rollback 条件を明文化する
5. 昇格条件を満たした時だけ次のステージへ進める

## 必ず確認すること

- broker 固有 symbol と spread
- VPS / terminal 安定性
- 約定失敗時の挙動
- 日次損失と週次損失の停止条件
- forward と backtest の乖離

## 出力

- Stage
- Promotion gate
- Monitoring items
- Rollback trigger
- Next checkpoint

## 参照

- `references/promotion-gates.md`
