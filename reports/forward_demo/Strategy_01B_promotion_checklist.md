# Strategy_01B Promotion Checklist

作成日: 2026-05-15

## Current Stage

現在は `demo forward` 準備完了候補。

Live 昇格は未承認。以下を満たすまで本番運用しない。

## Demo Start Checklist

- [ ] `USDJPY M5` のみで稼働している
- [ ] `SelectedStrategyMode=STRATEGY_01B_J_SHORT`
- [ ] 初期 `EnableTrading=false`
- [ ] preflight CSV が出力されている
- [ ] `preflight_status=PASS`
- [ ] `preflight_warnings` が空、または内容を説明できる
- [ ] `MagicNumber` が他EAと重複していない
- [ ] `RiskPercent <= 0.25`
- [ ] `MaxTotalOpenRiskPercent <= 0.25`
- [ ] `AllowOnlyOnePositionForStrategy01B=true`
- [ ] `UseEquityCurveGuard=true`
- [ ] `InpBlockUnsafeForwardDemoSettings=true`
- [ ] `MaxSpreadPoints=30.0` またはそれ以下
- [ ] CSV diagnostics が出力されている
- [ ] daily summary CSV が出力されている
- [ ] chart objects が描画される
- [ ] signal-only で reject reason が説明できる

## Demo Promotion Gate

demo auto execution に進む条件:
- [ ] signal-only 期間で想定外の symbol / direction がない
- [ ] `RejectReason` が想定どおり出る
- [ ] `unsafe_forward_demo_setting_blocked` が出ていない
- [ ] daily summary の `stop_condition_triggered=false`、または停止理由を説明できる
- [ ] `live_*` error が出ていない
- [ ] SL/TP が計算不能な候補は reject される
- [ ] spread 異常時に `spread_too_wide` で止まる

## Small Live Gate

小ロット本番に進める最低条件:
- [ ] 2週間以上の demo 稼働
- [ ] 30件以上の demo トレード
- [ ] 実約定の平均損失Rが -1R 付近に収まる
- [ ] 想定外の SL/TP ズレがない
- [ ] 日次 / 週次 / 月次の risk guard が正しく効く
- [ ] MaxDD_R が想定内
- [ ] backtest と比べてシグナル頻度が極端に違わない
- [ ] すべてのトレードを diagnostics から説明できる
- [ ] 注文エラーが連発していない
- [ ] `live_position_tracking_failed` が出ていない
- [ ] 本番に進める場合でも `RiskPercent <= 0.25` から開始する

## Immediate Stop

以下は即停止:
- [ ] 1日 `-1.5R`
- [ ] 週 `-4R`
- [ ] 月 `-6R`
- [ ] SL/TP なし注文
- [ ] `live_position_tracking_failed`
- [ ] `live_sl_tp_invalid`
- [ ] `live_lot_invalid`
- [ ] `unsafe_forward_demo_setting_blocked`
- [ ] `csv_log_output_failed`
- [ ] `missing_sl_tp_order`
- [ ] `unexpected_symbol`
- [ ] `live_order_send_failed` の連発
- [ ] 想定外 symbol
- [ ] MagicNumber 重複
- [ ] ログ出力停止

## Restart Gate

停止後に再開する条件:
- [ ] preflight を再実行し `PASS` を確認
- [ ] daily summary の `stop_reason` を説明済み
- [ ] diagnostics で該当候補または注文を追跡済み
- [ ] preset と chart input の差分を確認済み
- [ ] MagicNumber, symbol, timeframe, spread guard を再確認済み
- [ ] 再開直後は `EnableTrading=false` に戻して signal-only を確認

## Decision Rule

demo の目的は利益額を見ることではなく、実注文時にも R 単位の期待値検証が壊れないことを確認すること。

小ロット本番は、demo evidence がそろい、停止条件と再開条件を守れる状態になってから判断する。
