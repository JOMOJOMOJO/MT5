# Strategy_01B Risk Settings

作成日: 2026-05-15

## Accepted Default

forward demo の優先候補は `STRATEGY_01B_J_SHORT`。

推奨 preset:
- `reports/presets/ExpectedValue_NWave_J_SHORT_demo_conservative.set`

初期値:
- `EnableTrading=false`
- `RiskPercent=0.25`
- `MaxTotalOpenRiskPercent=0.25`
- `MaxDailyLossR=1.5`
- `MaxWeeklyLossR=4.0`
- `MaxMonthlyLossR=6.0`
- `StopTradingAfterMaxDD_R=15.0`
- `MinBarsBetweenEntries=5`
- `AllowOnlyOnePositionForStrategy01B=true`
- `MaxSpreadPoints=30.0`

`EnableTrading=false` が初期値。デモ口座で手動確認してから `true` に切り替える。

## Why J_SHORT First

Risk guard 回帰では、`J_SHORT_MODE` は strict guard を入れても期待値と PF が崩れにくかった。

Full window:
- Guard OFF: 340 trades, ExpectancyR `+0.1467`, PF `1.2711`, MaxDD_R `11.5070`
- Guard ON Conservative: 327 trades, ExpectancyR `+0.1541`, PF `1.2863`, MaxDD_R `9.5070`
- Guard ON Very Conservative: 318 trades, ExpectancyR `+0.1553`, PF `1.2889`, MaxDD_R `9.0000`

`C_SHORT_MODE` は広い候補として残すが、very conservative full-window では 505 trades から 159 trades まで落ち、ExpectancyR が `+0.0218` まで低下した。初回 demo では `J_SHORT` を優先する。

## Position Risk

1トレードの最大リスクは `0.25%`。

このEAは SL 幅からロットを逆算し、`OrderCalcProfit()` ベースで 1 lot の SL 損失額を評価する。固定ロット、ナンピン、マーチンゲールは使わない。

## Open Risk

`MaxTotalOpenRiskPercent=0.25` と `AllowOnlyOnePositionForStrategy01B=true` により、Strategy_01B は実質 1ポジション運用にする。

`MaxManagedPositions=2` は既存検証との互換のため残すが、Strategy_01B の実効制限は one-position guard を優先する。

## Period Loss Guards

Forward demo の停止ライン:
- Daily: `MaxDailyLossR=1.5`
- Weekly: `MaxWeeklyLossR=4.0`
- Monthly: `MaxMonthlyLossR=6.0`
- Equity curve DD: `StopTradingAfterMaxDD_R=15.0`

出力される主な reject:
- `daily_loss_r_blocked`
- `weekly_loss_r_blocked`
- `monthly_loss_r_blocked`
- `max_drawdown_r_blocked`
- `total_open_risk_blocked`
- `min_bars_between_entries_blocked`
- `strategy01b_one_position_blocked`

## Spread Guard

USDJPY M5 demo の初期値は `MaxSpreadPoints=30.0`。

これはバックテスト時の `50.0` よりも実運用向けに厳しめ。シグナル頻度が減る可能性はあるが、初回 demo では約定品質を優先する。

## Very Conservative Preset

`reports/presets/ExpectedValue_NWave_J_SHORT_demo_very_conservative.set` は、少額・初回接続確認向け。

設定:
- `RiskPercent=0.10`
- `MaxTotalOpenRiskPercent=0.10`
- `MaxDailyLossR=1.0`
- `MaxWeeklyLossR=3.0`
- `MaxMonthlyLossR=5.0`
- `StopTradingAfterMaxDD_R=10.0`
- `MinBarsBetweenEntries=8`

これは運用安全側 preset であり、今回の full-window expectancy evidence は `0.25%` risk guard を主根拠にする。

## Hard Rule

本番運用はまだ不可。demo で注文経路、SL/TP、risk guard、ログ説明可能性を確認する段階に留める。

## Forward Demo Safety Block

`InpBlockUnsafeForwardDemoSettings=true` を forward demo の標準にする。

このガードはエントリー条件を変えるものではない。`EnableTrading=true` のときだけ、forward demo として危険な設定を `unsafe_forward_demo_setting_blocked` で止める。

ブロック対象:
- `symbol != USDJPY`
- chart timeframe が `M5` 以外
- `RiskPercent > 0.25`
- `MaxTotalOpenRiskPercent > 0.25`
- `AllowOnlyOnePositionForStrategy01B=false`
- `UseEquityCurveGuard=false`
- `MaxSpreadPoints > 30.0`

Signal-only の `EnableTrading=false` では warning と preflight CSV を出し、検証自体は継続する。これは設定ミスの早期発見が目的であり、ロジック改善ではない。

## Daily Risk Readout

daily summary CSV の主要項目:
- `realized_profit_r`
- `max_daily_dd_r`
- `consecutive_losses`
- `daily_loss_r_blocked_count`
- `total_open_risk_blocked_count`
- `stop_condition_triggered`
- `stop_reason`

停止判定は日次CSVで説明できることを必須にする。説明できない停止、ログ欠損、SL/TP 欠損、position tracking failure は strategy の問題ではなく運用停止理由として扱う。
