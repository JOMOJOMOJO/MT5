# USD100 Challenge Mode Design

Scope: `Strategy_01B_J_SHORT g039` is frozen. This mode changes only sizing, margin blocking, DD/ruin guards, and logging for a 100 USD high-risk challenge. Entry filters, C/J conditions, TP/SL, fixed 1.5R exit, and g039 parameters were not changed.

## Inputs Added

- `InpUseUsd100ChallengeMode`
- `Usd100ChallengeInitialBalance`
- `Usd100UseMinLotOnly`
- `Usd100MaxLot`
- `Usd100MaxEffectiveRiskPercent`
- `Usd100HardBlockEffectiveRiskPercent`
- `Usd100BlockIfMarginInsufficient`
- `Usd100BlockIfEffectiveRiskTooHigh`
- `Usd100SoftPauseDDPercent`
- `Usd100HardStopDDPercent`
- `Usd100RuinDDPercent`

## Behavior

When `InpUseUsd100ChallengeMode=true`, the account must be USD. If `Usd100UseMinLotOnly=true`, the EA does not increase volume from `RiskPercent`; it uses broker minimum lot, capped by `Usd100MaxLot`. For this broker/tester that means 0.01 lot.

If `Usd100UseMinLotOnly=false`, the hybrid behavior is: below 1000 USD use 0.01 lot; above 1000 USD use `SmallCapitalTier2RiskPercent`; above 10000 USD use `SmallCapitalTier3RiskPercent`.

Risk checks:

- Effective risk > `Usd100HardBlockEffectiveRiskPercent`: reject with `usd100_effective_risk_hard_blocked`.
- Effective risk > `Usd100MaxEffectiveRiskPercent`: warning, or reject with `usd100_effective_risk_too_high` when `Usd100BlockIfEffectiveRiskTooHigh=true`.
- Insufficient margin: reject with `usd100_margin_insufficient`. Repeated margin insufficiency sets ruin reason `usd100_repeated_margin_insufficient`.
- DD stops: `usd100_soft_pause_dd`, `usd100_hard_stop_dd`, `usd100_ruin_dd`.

Compile evidence: `reports/compile/ExpectedValue_NWave_Scalper_usd100_challenge_compile.log` reports 0 errors / 0 warnings.
