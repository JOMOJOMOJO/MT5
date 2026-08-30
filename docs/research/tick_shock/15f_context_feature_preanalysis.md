# Step 15F causal context feature pre-analysis

## Scope and hypothesis

Trial `TS15F-CONTEXT-V1` asks whether context known at +60s or +120s separates
CONTINUATION, REVERSAL and NO_TRADE on actual Bid/Ask returns at 5/10/15
minutes. March 2025 is entirely `DEVELOPMENT_ONLY`.

H0: causal context plus frozen shock structure does not improve block-level
spread-only executable return over context-only, always-continuation,
always-reversal or no-trade baselines.

Primary outcome is chosen-action spread-only executable return. Secondary
outcomes are action-positive probability, MFE/MAE, recross, 1.25x-spread
sensitivity, coverage and calibration. Path labels are outcomes and prohibited
features. Formal net remains unavailable.

## Fixed feature and clock contract

The feature registry is
`reports/analysis/tick_shock/step15f/feature_registry.csv`. It contains at most
36 numeric/binary model features across trend, momentum/position, volatility,
liquidity/cost, shock structure, causal USD context and time. Additional raw
fields are provenance/diagnostics only. EMA20/50 and ATR14 are
`ENGINEERING_ASSUMPTION_TO_BE_VALIDATED`; their periods will not be changed
after March outcomes.

Bars are built only after a later minute proves closure. M5/M15 values use the
last fully closed aligned group. EMA index 0 means the last closed bar;
EMA slope is `(EMA_t-EMA_t-3)/ATR14_t`. Distances divide by the same-timeframe
last-closed ATR14. Zero/invalid ATR fails closed. Trailing returns exclude the
current incomplete minute. Daily high/low contains only observations received
through the decision quote.

The causal USD factor is the median of available standardized trailing returns
after multiplying USDJPY/USDCHF/USDCAD by +1 and EURUSD/GBPUSD/AUDUSD by -1.
At least three observed pairs are required. Only symbol states processed by
the global watermark through the decision time are eligible; final cluster
breadth is forbidden.

Primary decision clocks are anchor +60s and +120s. Confirmed, +30s and the
causal state transition are secondary. Exits are anchor +300/+600/+900s and
must be strictly after entry. Long uses Ask/Bid; Short Bid/Ask. NO_TRADE return
is zero.

## Missing, controls and dependence

Missing/zero ATR, insufficient closed bars, fewer than three USD pairs,
stale/fallback quote or invalid spread fails closed for the affected feature or
row. No full-sample imputation is allowed. Training-fold median imputation plus
missing indicators is allowed only inside the model pipeline.

Non-shock anchors use a deterministic 15-minute broker-server grid. A control
is armed only when the symbol is outside shock ACTIVE/COOLDOWN and has complete
history. A shock during its 15-minute outcome invalidates it, thereby enforcing
the pre/post 15-minute purge without future selection. Pseudo-direction is the
sign of the last fully closed 5-minute return; zero is no control. Reuse is at
most once per symbol/grid anchor.

Episode and all its checkpoints remain in one fold. Five expanding
chronological folds use a 15-minute purge and 15-minute embargo, retaining
market-cluster blocks. Scaling, imputation, bucket boundaries and inner model
selection are training-only. Bootstrap unit is broker-server day; this is not
formal OOS.

## Models and multiplicity

Finite model families:

- Elastic Net regression: alpha {0.001,0.01,0.1}, l1 ratio {0.1,0.5,0.9};
- Elastic Net logistic: C {0.1,1,10}, l1 ratio {0.1,0.5,0.9};
- shallow gradient boosting: depth {1,2}, estimators {50,100}, learning rate
  {0.03,0.1}.

Random seed is 20260831. Inner chronological validation chooses among the
finite configurations. Primary model families are context-only and
context-plus-shock. Univariate boundaries are training-fold quintiles. Twelve
registered interactions are listed in the feature spec; no exhaustive search
is permitted. Holm FWER controls primary action/checkpoint/horizon tests;
Benjamini-Hochberg is descriptive only.

## Candidate gate and statuses

At most three human-readable rules with at most four predicates may be frozen.
Each requires N>=200, adequate day/market blocks, positive spread-only mean,
day-block 95% lower bound >0, Holm one-sided p<0.05, 5/5 fold sign, all-positive
leave-one-symbol-out, positive 1.25x-spread mean, adjacent-threshold stability,
no symbol concentration and improvement over context-only. March-derived rules
are `DEVELOPMENT_DERIVED_NOT_VALIDATED`.

If no rule passes, status is `NO_CONTEXT_RULE_HYPOTHESIS_FROZEN`. Permitted
study statuses are those in the Step 15F instruction. `COST_MODEL_INCOMPLETE`,
`FORMAL_NET_EXPECTANCY_UNAVAILABLE`, `EDGE_UNDETERMINED` and
`PRODUCTION_NOT_ELIGIBLE` remain mandatory.

Feature/model spec hashes are hashes of the canonical registry/trial CSVs and
are recorded after those preregistration files are generated, before outcome
production. No RR, SL/TP, detector, strategy or production order change is in
scope.

- feature spec SHA-256: `074C40B21F804CEDB414FA0C75DD1A101B7DF808F6254000B641C134C282B597`
- model-family SHA-256: `29A00C165566C46E7102D6B4C6AC14482DCA88E8F4ABAAB8B5DE2E388A60C338`
- deterministic seed: `20260831`
