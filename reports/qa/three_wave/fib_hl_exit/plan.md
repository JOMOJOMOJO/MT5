# Frozen experiment: closed Fib entry and one-time HL exit replacement

2026-09-25. Production EA unchanged. New tester-only research EA.

Entry: existing M5/M1 CHoCH/Wave1 recognition, M1/M5 pivots2/2, then first fully formed M1 bar that opens at/after M1 Wave1 high confirmed_time and closes within retracement .5-.618. No wick-only touch and no pre-confirmation candle. Buy next available tick Ask after that close. EMA ordered+rising ON. One first eligible decision per M5 parent; no retries after gating. No OR with READY in this separate experiment.

Initial SL = reversal low -10 points; initial TP RR1.2; Equity risk1%; existing order/exposure/cooldown15min preserved. Compare dynamic OFF vs ON on exactly the same entry candidates, 2025Q1 Model4, initial USD10000. No threshold optimization.

User explicitly selected new SL = first valid post-entry confirmed M1 Wave2 HL -10 points. One replacement, not repeated trailing. Require newSL>oldSL and newSL<actual fill. NewTP = fill+(fill-newSL)*1.2, tick-normalized. HL pivot may occur before fill but confirmation must be strictly after entry; same M1 attempt only. If newTP already reached (or newSL crossed) when known, close at current available market. Keep old bracket on stop/freeze/rejection and retry at most once/sec for actual requests. Reconcile server modifications before base protection to avoid restoring old levels on delayed acknowledgment. Skip impossible nonpositive-risk geometry. Keep initial fill risk for R accounting.

Short smoke + native policy checks before full tests. Report net R relative to initial risk, money/PF/DD/monthly entries, counts of modifications/immediate closes/skips, and data quality. Q1 is previously viewed data, not OOS. Live restart/resumption not supported for research state.
