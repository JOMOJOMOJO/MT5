# Step 15M Direct Action TP-First Prediction results

## One-page outcome

Step 15M found an OOF ranking signal for whether an action reaches TP first,
but it did not produce a tradeable policy. The primary global LightGBM reached
action-row AP 0.0997 against a 0.01543 base rate and ROC-AUC 0.8961. Nevertheless,
its selected direction was correct for only 26 of the 50 OOF tradeable episodes
(52%), and every registered Top-N and score-threshold policy had materially
negative expectancy. The best registered Top-N result was Top 25: 4 TP / 21 SL,
-0.584R mean, with cluster-bootstrap 95% interval [-0.896R, -0.168R].

The classifier mostly rediscovers whether an episode may contain a clean move;
it does not reliably identify continuation versus reversal. Spread features
again dominate the descriptive importance tables. No positive fold, global
policy, with-symbol policy, or USDJPY-only policy was observed.

Verdicts:

- `DIRECT_ACTION_SIGNAL_FOUND`
- `NO_TRADE_FILTER_SIGNAL_FOUND` (ranking enrichment only)
- `DIRECT_ACTION_TRADE_EDGE_NOT_FOUND`
- `DIRECTION_SELECTION_SIGNAL_NOT_FOUND`
- `USDJPY_SPECIFIC_EDGE_NOT_FOUND`
- `REGIME_INSTABILITY_CONFIRMED`
- `OOS_VALIDATION_NOT_JUSTIFIED_FOR_THIS_FORMULATION`
- `PRODUCTION_NOT_ELIGIBLE`

## Population, actions, and costs

- Episodes: 2,696; action rows: 5,392.
- TP-first actions: 188: continuation 84 and reversal 104.
- Both actions TP-first: 0; both actions SL-first: 2,508 episodes.
- OOF episodes/action rows: 1,620 / 3,240; OOF TP-first actions: 50.
- TP/SL/hold: 0.40 ATR / 0.25 ATR / 900 seconds.
- All analysis-ready action paths reached TP or SL; TIMEOUT rows were 0.
- TP is +1.6R and SL is -1R. Executable Bid/Ask paths include spread.
- Strategy Tester commission fields were observed as zero, so gross and
  observed-tester net R are equal. Live Vantage commission remains unobserved.
- Subtracting 0.02R, 0.05R, or 0.10R per trade only makes every result worse.
- Exact stop-gap and exit-slippage reconstruction is unavailable from the
  persisted aggregate path; -1R SL treatment is therefore optimistic.

No new MT5 run was needed: the frozen Step 15K path has complete 900-second
first-touch evidence for all 2,696 Step 15L analysis-ready episodes.

## Primary model and direct policy

| Model | Action AP | ROC-AUC | Correct direction among 50 | All-best-action R |
|---|---:|---:|---:|---:|
| Logistic, no symbol | 0.0800 | 0.8818 | 28/50 (56%) | -0.9551R |
| LightGBM, no symbol | 0.0997 | 0.8961 | 26/50 (52%) | -0.9583R |
| LightGBM, with symbol | 0.0985 | 0.8966 | 24/50 (48%) | -0.9615R |
| LightGBM, USDJPY only | 0.1196 | 0.8014 | 20/39 (51.3%) | -0.9053R |

The higher AP is a real ranking improvement over the rare action base rate, but
52% direction accuracy is indistinguishable from the practical 50/50 problem.
Scores for the losing action of a tradeable episode often remain high because
both action rows share the same episode-level liquidity and volatility state.

### Registered global Top-N frontier

| Top N | C/R selected | TP | SL | Both-SL selected | Wrong direction | Mean R | 95% cluster CI |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 25 | 5 / 20 | 4 | 21 | 18 | 3 | -0.5840 | [-0.8960, -0.1680] |
| 50 | 7 / 43 | 6 | 44 | 38 | 6 | -0.6880 | [-0.8960, -0.4280] |
| 75 | 12 / 63 | 10 | 65 | 59 | 6 | -0.6533 | [-0.8267, -0.4453] |
| 100 | 19 / 81 | 10 | 90 | 82 | 8 | -0.7400 | [-0.8700, -0.5840] |
| 150 | 31 / 119 | 11 | 139 | 125 | 14 | -0.8093 | [-0.9133, -0.6880] |
| 200 | 41 / 159 | 17 | 183 | 165 | 18 | -0.7790 | [-0.8706, -0.6766] |
| 300 | 63 / 237 | 20 | 280 | 258 | 22 | -0.8267 | [-0.8967, -0.7495] |
| 500 | 96 / 404 | 23 | 477 | 453 | 24 | -0.8804 | [-0.9263, -0.8322] |

Break-even requires 38.46% TP when only +1.6R/-1R outcomes exist. The best
registered TP rate was 16% at Top 25. The most selective registered score
threshold, >=0.60, produced 9 TP / 61 SL and -0.6657R. No threshold was adopted.

The Top-25 filter excludes 1,552 of 1,570 OOF both-SL episodes, but also keeps
only 7 of 50 tradeable episodes and chooses the wrong direction for 3 of those
7. This is why strong no-trade rejection does not translate into expectancy.

## Fold and regime stability

| Fold | Episodes | Action positives | Action AP | Best-action TP/SL | Mean R |
|---:|---:|---:|---:|---:|---:|
| 1 | 408 | 16 | 0.1373 | 12 / 396 | -0.9235 |
| 2 | 402 | 10 | 0.1995 | 4 / 398 | -0.9741 |
| 3 | 404 | 6 | 0.1158 | 3 / 401 | -0.9807 |
| 4 | 406 | 18 | 0.1079 | 7 / 399 | -0.9552 |

AP exceeded each rare fold base rate, but trade expectancy was negative in all
four folds. Weekly all-best-action expectancy was -0.8934R, -0.9695R, -0.9830R,
and -0.9217R from the partial week of March 10 through March 31. The direct
policy therefore does not survive March's later regime in an economic sense.

## USDJPY and symbol results

The primary global best-action policy produced 20 TP / 529 SL on USDJPY
(-0.9053R). The separately trained USDJPY-only model also selected the correct
direction for only 20/39 tradeable USDJPY episodes; its Top 25 was 3 TP / 22 SL
(-0.688R). Adding symbol identity to the global model slightly reduced AP and
direction accuracy. There is no `USDJPY_SPECIFIC_EDGE_CANDIDATE` under this
geometry and action formulation.

AUDUSD and USDCHF produced no OOF TP under the selected action, EURUSD produced
5/151, and USDCAD 1/448. These results do not support a portable cross-symbol
trade policy.

## Ablation and interpretation

Global LightGBM action AP for A/B/C/D/E was 0.1032, 0.0994, 0.0999, 0.0931,
and 0.0997. All-best-action expectancy was between -0.9631R and -0.9502R.
No feature group produced a positive economic policy, so the March sample was
not used to select a smaller production feature set.

Descriptive permutation importance was led by `spread_5s_atr`,
`spread_10s_atr`, `spread_atr_t0`, `spread_30s_atr`, realized 60-second
movement, and action-aligned 900-second return. The dominance of directionless
cost/regime variables, together with 52% action direction accuracy, supports
the interpretation that the signal is primarily a no-trade/clean-path signal
rather than a direction signal. SHAP and gain tables are descriptive refits,
not OOF causal explanations.

Continuation-only and reversal-only LightGBM achieved AP 0.1312 and 0.1305,
respectively, but trading every scored episode remained -0.9615R and -0.9583R.
Separate direction models therefore do not rescue the policy.

## Step 15L comparison

On the identical OOF population, always continuation was 24 TP / 1,596 SL
(-0.9615R) and always reversal was 26 TP / 1,594 SL (-0.9583R). At Top 25,
Step 15L Clean ranking plus reversal and Step 15M direct action both reached
4 TP / 21 SL (-0.584R). At Top 100, the Step 15L Clean ranking plus reversal
was 13 TP / 87 SL (-0.662R), while Step 15M was worse at 10 / 90 (-0.740R).
The direct formulation did not improve the frozen two-stage proxy.

A formal two-stage Clean-selector/direction-classifier policy cannot be fully
replayed because Step 15L did not persist per-episode OOF direction scores for
all candidate episodes. The available Step 15L aggregate direction result was
already near chance; it is not reclassified as evidence here.

## Integrity and reproducibility

- Model QA: 18/18 PASS.
- Independent recalculation: 35/35 PASS.
- Deterministic rerun: 16 generated files, SHA differences 0.
- Feature timestamp, target-feature leakage, duplicate action key, episode fold
  overlap, market-cluster fold overlap, and OOF chronology violations: 0.
- The Step 15L Top-327 audit reproduced exactly: continuation TP 23, reversal
  TP 22, both-SL 282.
- Orders and trades: 0. Production EA and strategy parameters were unchanged.

## Decision

Step 15M answers the EA-facing question negatively for the registered March
formulation: the available causal features cannot choose continuation,
reversal, or no-trade with positive OOF expectancy at TP 0.40 ATR / SL 0.25 ATR.
The evidence does not justify freezing this model for unused-period OOS, because
no March policy crossed the economic feasibility gate. Further work would need
a genuinely different causal information source or problem formulation, not a
finer March threshold search.

Evidence is under `reports/analysis/tick_shock/step15m/`; the implementation is
`tools/tick_shock/analyze_step15m_direct_action.py`, and the independent oracle
is `tools/tick_shock/step15m_independent_oracle.py`.
