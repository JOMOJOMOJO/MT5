# USD Small Capital Challenge Mode Design

Scope: this mode is an operational risk/sizing layer for `Strategy_01B_J_SHORT g039`. It does not change entry filters, C/J strategy conditions, TP/SL construction, fixed 1.5R exit, or g039 parameters.

## New Mode

`InpUseSmallCapitalChallengeMode=true` enables USD equity/balance based automatic risk selection. When `SmallCapitalRequireUsdAccount=true`, non-USD accounts are blocked for live trading and warned in preflight. `SmallCapitalUseEquityInsteadOfBalance=true` uses account equity as the tier base; otherwise it uses balance.

Default aggressive ladder:

- Equity < 1000 USD: 10% risk
- 1000 <= Equity < 10000 USD: 5% risk
- Equity >= 10000 USD: 1% risk

The safer test ladder used in this report changes the first two tiers to 5% and 2%, keeping 1% above 10000 USD.

## Min Lot And Effective Risk

The sizing path calculates desired risk money from the selected tier, then calculates lot size from `OrderCalcProfit()`-based loss at SL. If calculated volume is below broker minimum and `SmallCapitalAllowMinLotOverride=true`, the EA can force `min_lot`. The final lot is logged with:

- `calculated_lot_before_rounding`
- `min_lot` / `lot_step` / `final_lot`
- `final_lot_reason`
- `actual_risk_money_at_final_lot_usd`
- `effective_risk_percent_at_final_lot`
- `margin_required` / `free_margin_after_entry_estimate`

If final-lot effective risk exceeds `SmallCapitalMaxEffectiveRiskPercent`, the candidate is rejected with `small_capital_effective_risk_too_high`. If margin is insufficient, it is rejected with `small_capital_margin_insufficient`.

## Challenge DD And Ruin Controls

Challenge-only DD guards are separate from the normal production DD guards:

- `small_capital_soft_pause_dd` at `SmallCapitalSoftPauseDDPercent`
- `small_capital_hard_stop_dd` at `SmallCapitalHardStopDDPercent`
- `small_capital_ruin_dd` at `SmallCapitalRuinDDPercent`

Ruin status also records zero/negative equity or balance, repeated margin insufficiency, and margin stop-out style conditions. Logged fields include start/current balance, current/peak/min equity, max DD%, min margin level, `ruin_triggered`, and `ruin_reason`.

## Safety Notes

Two implementation safeguards were added during validation:

- StrategyMode static filters now run before lot/margin sizing so rejected non-strategy candidates cannot advance small-capital margin failure counters.
- Normal controlled-demo limits such as `MaxTotalOpenRiskPercent <= 0.25` are bypassed only when small-capital challenge mode is active; the challenge mode uses final effective risk and challenge DD guards instead.

Compile result: `reports/compile/ExpectedValue_NWave_Scalper_usd_small_capital_compile.log` reports 0 errors / 0 warnings.
