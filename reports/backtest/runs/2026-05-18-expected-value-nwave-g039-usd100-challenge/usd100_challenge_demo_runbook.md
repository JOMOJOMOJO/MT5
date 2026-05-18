# USD100 Challenge Demo Runbook

This runbook is only for high-risk 100 USD challenge demo. It is not normal small live or production.

## Preset

Use: `reports/presets/ExpectedValue_NWave_J_SHORT_g039_usd100_minlot_challenge_demo.set`

Key settings:

- `EnableTrading=true`
- `InpUseUsd100ChallengeMode=true`
- `Usd100UseMinLotOnly=true`
- `Usd100MaxLot=0.01`
- `Usd100MaxEffectiveRiskPercent=10.0`
- `Usd100HardBlockEffectiveRiskPercent=15.0`
- `Usd100BlockIfMarginInsufficient=true`
- `Usd100BlockIfEffectiveRiskTooHigh=true`
- `Usd100SoftPauseDDPercent=40.0`
- `Usd100HardStopDDPercent=70.0`
- `Usd100RuinDDPercent=95.0`
- `InpBlockNonDemoAccountForForwardDemo=true`

## Daily Checks

- Confirm account currency is USD.
- Confirm demo account unless explicitly approved for high-risk real-money challenge.
- Confirm symbol/timeframe: USDJPY M5.
- Confirm final lot remains 0.01.
- Check `effective_risk_percent_at_final_lot`; any accepted trade above 10% should not occur with the supplied preset.
- Check rejects: `usd100_margin_insufficient`, `usd100_effective_risk_too_high`, `usd100_effective_risk_hard_blocked`.
- Stop immediately on any `live_*` error, missing SL/TP, non-USD account, non-demo account, or logging failure.

## Demo Gate Before Real Money

- At least 30 closed demo trades.
- No margin insufficiency.
- No accepted trade above 10% effective risk with the final preset.
- No hard block above 15%.
- No live errors.
- Deal-level CSV explains all entries/exits.
- MaxDD% remains psychologically acceptable for a high-risk 100 USD challenge.
