# Frozen feature research protocol

Research only. No orders, no filters, no changes to production EA or Shared engine.

## Candidate universe
At each new M1 bar, use the existing 6000 M1 / 1800 M5 history and unchanged Shared conditions. An instrumented COPY emits every closed M1 CHoCH and valid confirmed HL observed before the parent's first READY. The original READY remains unchanged. Record HL revisions; primary statistics use the FIRST HL per M5-parent/M1-CHoCH attempt. Do not require Fib50. Preserve origin invalidation and the original M5 breakout deadline. Stage counts overlap; unique parent and unique reversal-attempt counts are separate.

## Features, all available at signal time
- Native M5 EMA20 PRICE_CLOSE, ATR14, iADX14 (not iADXWilder), +DI/-DI from the last CLOSED M5 bar.
- EMA slope: (EMA[t]-EMA[t-3])/(3*ATR[t]); prior slope uses t-3 to t-6 and the same current ATR. Deceleration proxy = current minus prior slope; positive means slope is becoming more positive, not necessarily a verified trend reversal.
- EMA distance = (last closed M1 close - last closed M5 EMA20)/M5 ATR14.
- Previous descent ER: absolute close displacement / sum absolute close changes from the last confirmed M5 high preceding the origin low to the origin-low bar. Log anchors; missing/zero paths remain missing.
- Wave1 ER: same close-path formula from frozen M5 origin-low bar to frozen Wave1-high bar. Both ERs are unsigned [0,1]; signed net movement is also logged so an alleged descent can be inspected.
- Wave2 retracement: running deepest CLOSED M1 low AFTER the Wave1-high M5 bar closes, relative to frozen M5 Wave1 range. Also log current close retracement. This is observed depth, not the future final Wave2 low.
- Wave2 duration: elapsed minutes since Wave1-high M5 bar closed, plus time since that pivot became knowable.
- CHoCH break strength: (CHoCH closed M1 close - frozen return high)/ATR14 M1 of that CHoCH bar, frozen across later stages.

## Outcomes and costs
Independent overlapping shadow trades, not executable portfolio P/L. Entry is actual first new-bar Ask; exits checked on subsequent native Bid ticks (including entry tick). RR=1 fixed, SL buffer=10 points. Main SL: CHoCH reversal low, HL/READY current HL. A second control uses reversal-low SL for all stages. Invalid entry geometry remains recorded. No occupancy/cooldown filters. No commission/swap/slippage model; spread is included. R is price-distance R, not converted account-currency P/L.

RR1 first passage: TP/SL or mark-to-market at the first tick at/after 240 elapsed minutes. Report timeout and end-censor counts. MFE/MAE both to exit and fixed 60 minutes; incomplete fixed horizons remain flagged. Outcomes are future LABELS kept in a separate CSV, never signal features.

## Windows, bins and reproducibility
- Smoke: 2025-03-03 to 03-08, repeated byte-for-byte.
- Discovery: 2025-01-01 to 04-01; replication: 2025-05-01 to 08-01. These are already-seen strategy windows, not pristine OOS. Feature relationships have not been fitted before this protocol.
- All three stages in BOTH periods, no selection between runs. Full discovery run repeated to verify candidate/feature/outcome identity.
- Four marginal quantile bins per feature from discovery candidates, pooled stages (one vote per attempt/stage; first HL only), frozen for replication. No threshold search, no combinations or best-bin optimizer.
- Report distributions, N, months, candidates/month, win rate, mean R, MFE/MAE, timeouts and censoring for EVERY bin and stage. Missing values get a separate row.
- Exploratory differences: winner/loss standardized mean difference and top-vs-bottom bin R contrast, both periods. Cluster-bootstrap confidence intervals by M5 parent; do not treat stages/revisions as independent confirmations. Multiple-feature inspection is descriptive, not statistical proof of an edge.
- Frequency target means >=20 valid primary candidates PER calendar month (40 preferred), not merely six-month average; distinct opportunities and stages are not added together. Report whether each fixed bin could retain this before proposing a follow-up filter experiment. No filter adoption in this task.

## Analysis clarifications (no trading condition changes)
- ER can equal 1 for many waves. Keep the pre-frozen edges and empty overflow bin; top-vs-bottom contrast uses the highest occupied DISCOVERY bin, frozen across replication, rather than comparing against a mechanically empty ER>1 bin.
- Merge parent-bootstrap clusters if two parent setups share the identical M1 CHoCH. Report identical-time candidates separately; they are not two executable entries.
- After all marginal comparisons, include one explicitly POST-HOC frequency illustration: excluding the already-frozen top CHoCH-break-strength bin. This is a next-experiment hypothesis only, not a threshold search or adopted rule. Its result is not independent validation because the same two periods suggested the hypothesis.
