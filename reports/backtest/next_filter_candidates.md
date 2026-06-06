# Next Filter Candidates

## Candidate 1: Regime Quality Gate

- Target: avoid years/segments where LowerTF SL increases entries without compensating expectancy.
- Evidence: 2024 fails despite short-period success; 2025 and 2026YTD improve in different symbol/direction profiles.
- Risk: high. A broad regime label can overfit if derived from only three annual windows.
- Minimal next test: one fixed gate using trend age + trend strength + ATR percentile buckets, no RewardR/SL changes.

## Candidate 2: Signal-Specific Risk Gate

- Target: keep micro/candle entries only when SL ATR and entry distance buckets are in historically stable zones.
- Evidence: LowerTF SL changes trade count and stop geometry; weak years may be stop-width/noise dominated.
- Risk: medium-high. Needs yearly validation and FX/XAU split.

## Candidate 3: 2024 Rejection Classifier

- Target: identify whether 2024 failure is mostly trend-age, volatility, session, or symbol-direction exposure.
- Evidence: annual PF ties baseline, so a filter must explain 2024 specifically without removing 2025/2026 winners.
- Risk: medium. This should stay diagnostic until it survives 2024/2025/2026YTD.

## Recommendation

Do not tune RewardR or SL again. The next task should be a fixed Regime Quality Gate diagnostic based on this report. Stop if it improves only XAUUSD, only one direction, or fewer than two of 2024/2025/2026YTD.
