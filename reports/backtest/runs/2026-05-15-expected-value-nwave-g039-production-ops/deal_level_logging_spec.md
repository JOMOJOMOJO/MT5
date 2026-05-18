# Deal-Level Logging Spec

File pattern: `Strategy_01_NWave_ExpectedValue_<symbol>_<magic>_deal_level.csv`. Delimiter is semicolon. One row is written when a managed live-path position closes.

|Column|Meaning|
|---|---|
|setup_id|Setup identifier created from direction, signal time, and neckline/price context.|
|strategy_mode|Selected StrategyMode at entry.|
|signal_time|Closed-bar signal time.|
|order_send_time|Time the EA sent the market order.|
|planned_entry_price|Bid/Ask trade-plan entry before sending.|
|planned_sl|Planned stop loss price.|
|planned_tp|Planned take profit price.|
|planned_risk_points|Planned entry-to-SL distance in points.|
|actual_entry_deal_time|Actual entry deal time from MT5 history.|
|actual_entry_deal_price|Actual entry deal price.|
|actual_exit_deal_time|Actual exit deal time.|
|actual_exit_deal_price|Actual exit deal price.|
|exit_reason|stop_loss, take_profit, or other inferred close reason.|
|actual_risk_money|Estimated account-currency risk from actual entry to planned SL.|
|realized_profit_money|Profit including available profit, commission, and swap.|
|commission|Total commission for position deals.|
|swap|Total swap for position deals.|
|slippage_points_entry|Signed entry slippage in points; positive is unfavorable.|
|slippage_points_exit|Signed exit slippage in points; positive is unfavorable.|
|spread_at_entry|Spread points at plan/entry.|
|spread_at_exit|Spread points at exit handling.|
|realized_r|realized_profit_money / actual_risk_money.|
|account_balance|Balance after close.|
|account_equity|Equity after close.|
|peak_equity|EA-tracked peak equity.|
|drawdown_percent|EA-tracked current equity drawdown percent.|
|drawdown_r|EA-tracked current R drawdown.|

Use this file, not virtual diagnostics, for promotion decisions. Virtual results remain diagnostic only.
