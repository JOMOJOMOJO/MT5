# Wave / exit feature definitions

Entry decision cutoffs are ORDER.event_at and ORDER.signal_at. A lower bar is eligible only if known_at <= order and closed_at <= min(order, signal). Pivot event rows must precede ORDER. Subsequent EXIT wave anchors are never used. Actual fill metrics are named `actual_*` and distinguished from ORDER price metrics.

- **1R**: absolute actual FILL.entry_price - FILL.sl_price. EXIT.sl_price can have trailed. Net outcome R is execution_net_cash / execution_initial_risk_money; it includes actual logged execution costs and is not assumed equal to price R.
- **W1 duration/span**: ORDER-snapshot peak timestamp minus origin; signed peak-minus-origin. Confirmed-at times remain separate.
- **Entry progress**: signed(entry - W1 origin) / W1 span. 75% means a long has regained three quarters of its original upward W1, or a short has retraced down to the corresponding position of its downward W1.
- **W1 room R**: signed(W1 peak - actual fill) / initial price risk. It is geometry, not proof that W1 peak is resistance or TP.
- **W2 depth**: ORDER.retracement_ratio, the logged price extreme. This is not the M5 close beyond 61.8% invalidation condition. Wick depth >61.8% can therefore coexist with a valid close-based rule.
- **W2 age/duration**: ORDER time minus W1 peak time, divided by W1 peak-minus-origin duration. This is setup age after W1, not elapsed time from the W2 minimum alone.
- **W1 close ER**: W1 span / sum absolute increments of [origin price, causal M1 closes whose bar_time lies in origin..peak inclusive, peak price]. Uses source timestamps only after bars became available. It is an endpoint-and-close path statistic, not a tick-path efficiency estimate.
- **W1 pivot backtrack**: sum adverse directional increments along [origin, normalized confirmed M1 pivots strictly inside origin..peak, peak] / W1 span. Same-side consecutive extrema keep the more extreme; simultaneous H/L cause an ambiguity barrier and the feature is missing. Independent v1.90 reconstruction matches all19 available EA diagnostic rows within2.23e-16.
- **Preorigin countertrend agreement**: last8 normalized M5 pivots strictly before W1 origin and known before W1 candidate event. Mean of six high/high and low/low differences pointing opposite W1 direction. Missing if8 pivots unavailable after an ambiguity barrier. Used with fixed 50%/75% cuts, never searched.
- **W1/preleg**: W1 span divided by median absolute leg of the last8 preorigin M5 pivots. No prior8 means missing.
- **W1 breaks prior8 outer**: whether W1 peak exceeds max prior8 highs (long) / min prior8 lows (short). These prior levels were already known at candidate time.
- **M1 ATR14**: simple mean of the last14 true ranges of available M1 bars, not Wilder-smoothed ATR. Risk/ATR uses original FILL risk; body/ATR is the EA's separately logged trigger metric.
- **Pre15/pre60 close ER**: absolute first-to-last close displacement / sum absolute close differences among causal M1 bars beginning within the last15/60 minutes. Coverage counts reported separately. Range/ATR and range/risk use high-low width of those bars.
- **Spread/risk**: ORDER.spread_points / ORDER.risk_points. It is a decision-time ratio, not roundtrip total commissions/slippage.
- **MFE/MAE lower**: observed exit fill plus entire M1 bars with bar_time >= actual fill and closed_at <= actual exit. Missing boundary extrema are excluded. Lower is a lower bound on BID-price excursion, not guaranteed tradeable profit. SHORT still needs Ask to establish executable thresholds.
- **MFE/MAE upper**: all overlapping M1 bars. Entry minute may include prefill and exit minute may include postexit extrema. This upper bound is explicitly unsuitable for claiming exact tick-order profits.
- **Native MFE**: v1.90 daytrade POSITION_CLOSED.max_favorable_r, from EA executable quote tracking while position active. Risk-frozen row confirms immutable initial SL. Explicit CSV repair for unquoted delimiters is mandatory.
- **LOSS_WITHOUT_1R**: v1.90 native MFE below1R, or other versions' BID upper bound below1R. **REACHED_1R_THEN_LOSS** uses native MFE or full-bar BID lower bound >=1R. Boundary-only crossings are UNKNOWN. This is actual holding-period path classification, not a hypothetical strategy backtest.

All timestamps remain broker/source clock. UTC/JST conversion was not assumed. Versions are separate populations; Gold versions contain overlapping setup IDs. The fixed-bin CSV exposes every bin, including empty/missing interpretations where present; no winning subset was selected for EA adoption.
