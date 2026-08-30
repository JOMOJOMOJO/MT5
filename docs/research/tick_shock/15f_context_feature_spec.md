# Step 15F causal context feature specification

## Causal bar semantics

The bounded context engine receives real quotes in global-merge order. The
last quote within a millisecond wins. A minute is incomplete until a quote from
a later minute arrives. M5/M15 bars aggregate only fully closed M1 groups whose
right boundary is no later than the decision time. Missing aligned minutes
invalidate the derived timeframe feature rather than synthesizing a bar.

EMA uses the standard recursive alpha `2/(period+1)` after an SMA seed. ATR14
uses true range with the previous closed bar and Wilder recursion after the
first 14 values. EMA20/50 distance and slope are normalized by last-closed
ATR14. Realized volatility is RMS log return over completed 1/5/15-minute
windows. All denominators must be finite and positive.

## Model-visible families

The canonical registry fixes no more than 36 model-visible numeric/binary
features. Diagnostic fields such as raw Bid/Ask, episode ID, market cluster,
symbol, server day/hour, availability reason and observed pair count are not
silently promoted into numeric predictors.

The twelve allowed interactions are:

1. M5 EMA alignment x shock direction
2. M15 EMA alignment x shock direction
3. M1 EMA20 distance x severity
4. M5 alignment x repeat-direction balance
5. pre-trend x causal origin-recross flag
6. volatility regime x severity
7. spread/ATR x horizon
8. USD-factor alignment x shock direction
9. server-hour bucket x volatility regime
10. shock/pre-vol ratio x repeat count
11. tick activity x spread-normalization rate
12. daily-range position x shock direction

No interaction is derived from final path class, future cluster breadth or an
outcome value.

## Controls and outcomes

Controls use the same feature builder and Bid/Ask outcome recorder as shock
episodes. Deterministic anchors are 00/15/30/45 minutes. Controls overlapping a
shock or lacking the full 15-minute path are marked invalid; they are not
backfilled. Pseudo-direction is causal closed-5m return sign.

For each valid entry and exit, continuation and reversal are calculated as two
independent trades from actual sides. Spread 1.25x expands both entry and exit
around their fixed Mid. Formal net is blank unless commission and slippage are
validated for that symbol and run.

The implementation must preserve Step 15E episode/event/path/funnel identity,
all strategy parameters and production order count zero.

## Post-run implementation coverage guard

`TS15F-INTEGRITY-006` exercises `TS15FBuildFeatures` end to end and requires
F01 availability when completed M1 history and a positive ATR are present.
This guards against relying on MQL argument evaluation order when a helper both
returns a value and updates a validity flag. The expected value follows the
preregistered F01 availability contract; it does not change the feature
formula, period, threshold, model family or outcome.
