# Strategy_01B Forward Demo Runbook

作成日: 2026-05-15

対象EA: `mql/Experts/ExpectedValue_NWave_Scalper.mq5`

対象候補:
- Primary: `STRATEGY_01B_J_SHORT`
- Secondary/reference: `STRATEGY_01B_C_SHORT`

根拠:
- risk guard ON/OFF: `reports/backtest/runs/2026-05-15-expected-value-nwave-strategy01b-forward-demo-prep-risk-guards/summary.md`
- EnableTrading=true smoke: `reports/backtest/runs/2026-05-15-expected-value-nwave-strategy01b-forward-demo-prep-live-smoke/summary.md`

## Stage

現ステージは `demo forward preparation`。

本番運用はまだ不可。今回の目的は、既存の C_SHORT / J_SHORT 候補を勝つように改造することではなく、実注文経路・ログ・risk guard を確認したうえで、デモ口座で観察できる状態にすること。

## Recommended Start

推奨開始モードは `J_SHORT`。

最初に使う preset:
- `reports/presets/ExpectedValue_NWave_J_SHORT_demo_conservative.set`

初期状態:
- `EnableTrading=false`
- `SelectedStrategyMode=STRATEGY_01B_J_SHORT`
- `RiskPercent=0.25`
- `UseEquityCurveGuard=true`
- `AllowOnlyOnePositionForStrategy01B=true`
- `MaxTotalOpenRiskPercent=0.25`
- `MaxDailyLossR=1.5`
- `MaxWeeklyLossR=4.0`
- `MaxMonthlyLossR=6.0`
- `StopTradingAfterMaxDD_R=15.0`
- `MinBarsBetweenEntries=5`

## Phase 1: Signal-Only Check

1. デモ口座の `USDJPY M5` チャートに EA を適用する。
2. preset は `ExpectedValue_NWave_J_SHORT_demo_conservative.set` を読み込む。
3. `EnableTrading=false` のまま稼働する。
4. `SelectedStrategyMode` が `STRATEGY_01B_J_SHORT` であることを確認する。
5. `MagicNumber` が他EAと重複していないことを確認する。
6. チャート描画と CSV ログが出ることを確認する。
7. 最低 1-3 営業日、シグナル候補・RejectReason・spread reject を確認する。

この段階で注文は出さない。

## Phase 2: Demo Auto Execution

1. デモ口座でのみ `EnableTrading=true` に切り替える。
2. 最低 2-4 週間はデモ検証する。
3. 初期 risk は `0.25%` を上限にする。
4. 同時稼働は原則 `J_SHORT` のみ。`C_SHORT` は比較観察用で、同じ口座に重ねない。
5. すべての注文に SL/TP が同時設定されていることを確認する。

## Daily Checks

毎日見る項目:
- 当日の実現損益R
- `RejectReason` の上位理由
- `daily_loss_r_blocked` が想定どおり出るか
- `total_open_risk_blocked` が想定どおり出るか
- `spread_too_wide` の頻度
- `live_order_send_failed`
- `live_position_tracking_failed`
- `live_sl_tp_invalid`
- `live_lot_invalid`
- SL/TP なし注文が存在しないこと
- 稼働シンボルが `USDJPY` のみであること
- `MagicNumber` が重複していないこと
- CSV ログが更新されていること

## Weekly Checks

週次で見る項目:
- 週次損益R
- 週次最大DD_R
- 平均損失Rが -1R 近辺に収まっているか
- backtest と比べたシグナル頻度の大きなズレ
- spread reject の異常増加
- 注文エラーの有無
- broker 側の約定価格・SL/TP 距離のズレ

## Stop Conditions

以下に該当したら停止する:
- 1日で `-1.5R` 到達
- 週で `-4R` 到達
- 月で `-6R` 到達
- 連敗が backtest 最大連敗に近づく
- `MaxDD_R` が想定レンジを超える
- スプレッド異常が続く
- 注文エラーが連発する
- `live_position_tracking_failed` が1件でも出る
- `live_sl_tp_invalid` が1件でも出る
- `live_lot_invalid` が1件でも出る
- 想定外の通貨ペアで稼働している
- `MagicNumber` が重複している
- CSV ログが出力されない
- SL/TP なし注文が出る

## Restart Conditions

再開は次を満たす場合だけ:
- 停止理由がログから説明できる
- 設定ファイルと実チャート設定の差分を確認済み
- SL/TP、lot、MagicNumber、symbol を再確認済み
- 同じ問題が再発しない説明がある
- 再開後も最初は `EnableTrading=false` で signal-only 確認を挟む

## Notes

`EnableTrading=true` smoke は注文経路の安全確認であり、仮想検証期待値との完全一致を見るものではない。実約定・spread・金額ベース損益が入るため、forward demo では実損失Rが -1R 近辺に収まるかを重視する。

## Preflight CSV

EA は初期化時に preflight CSV を出力する。

確認するサンプル:
- `reports/forward_demo/preflight_sample_safe_j_short.csv`
- `reports/forward_demo/preflight_sample_unsafe_block.csv`

本番の確認項目:
- `preflight_status` が `PASS` であること
- `symbol=USDJPY`
- `timeframe=M5`
- `selected_strategy_mode=STRATEGY_01B_J_SHORT`
- `enable_trading` が意図した状態であること
- `risk_percent <= 0.25`
- `max_total_open_risk_percent <= 0.25`
- `allow_only_one_position_strategy01b=true`
- `use_equity_curve_guard=true`
- `max_spread_points <= 30.0`
- `digits`, `point`, `stops_level`, `freeze_level`, `lot_step`, `min_lot`, `max_lot` が broker 想定と矛盾しないこと

`preflight_status=BLOCK` の場合、`EnableTrading=true` では新規注文に進まない。`preflight_warnings` を確認し、設定を直してから EA を再初期化する。

## Daily Summary CSV

EA は日次 rollover と終了時に daily summary CSV を出力する。

確認するサンプル:
- `reports/forward_demo/daily_summary_sample_safe_j_short.csv`
- `reports/forward_demo/daily_summary_sample_unsafe_block.csv`

毎日見る項目:
- `total_signals`
- `live_entries`
- `closed_trades`
- `realized_profit_r`
- `max_daily_dd_r`
- `consecutive_losses`
- `reject_reason_top1` to `reject_reason_top3`
- `spread_too_wide_count`
- `daily_loss_r_blocked_count`
- `total_open_risk_blocked_count`
- `live_order_send_failed_count`
- `live_position_tracking_failed_count`
- `live_sl_tp_invalid_count`
- `live_lot_invalid_count`
- `stop_condition_triggered`
- `stop_reason`

`stop_condition_triggered=true` の日は停止理由を確認する。`daily_loss_r_reached`, `weekly_loss_r_reached`, `monthly_loss_r_reached`, `unsafe_forward_demo_setting_blocked`, `live_position_tracking_failed`, `live_sl_tp_invalid`, `live_lot_invalid`, `live_order_send_failed_repeated`, `missing_sl_tp_order`, `unexpected_symbol`, `csv_log_output_failed` は即時確認対象。

## Unsafe Setting Handling

`InpBlockUnsafeForwardDemoSettings=true` の場合、`EnableTrading=true` かつ以下の危険設定では新規注文をブロックする。

- `symbol != USDJPY`
- chart timeframe が `M5` 以外
- `RiskPercent > 0.25`
- `MaxTotalOpenRiskPercent > 0.25`
- `AllowOnlyOnePositionForStrategy01B=false`
- `UseEquityCurveGuard=false`
- `MaxSpreadPoints > 30.0`

この場合、diagnostics の `RejectReason` に `unsafe_forward_demo_setting_blocked` が出る。`EnableTrading=false` では warning を出しながら signal-only 検証を継続できる。

## Signal-Only To Demo Auto Gate

`EnableTrading=false` から `EnableTrading=true` に進む前に、最低限次を満たすこと。

- preflight が `PASS`
- daily summary が出力される
- diagnostics が更新される
- `RejectReason` が説明できる
- `unsafe_forward_demo_setting_blocked` が出ていない
- `live_*` 系エラーが当然 0
- signal frequency が backtest から極端にズレていない
- chart と preset の `MagicNumber` が重複していない
- broker symbol properties が想定外でない
