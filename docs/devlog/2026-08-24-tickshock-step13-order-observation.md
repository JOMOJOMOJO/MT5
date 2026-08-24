# Tick-shock Step 13 order observation

The tester-only order harness was extended to record request, deal, commission,
position, duplicate-replay, and end-position evidence. The Vantage real-tick
tester observed Long/Short server SL, server TP, and expert time close. Partial
fill, residual cancel, actual process restart, nonzero StopsLevel, and live
broker commission remain unobserved. See
`reports/tests/tick_shock/step13_order_observation/summary.md` and
`docs/research/tick_shock/13_order_observation.md`.
