# Strategy Charter

## Permanent North Star

- Build MT5 strategies that can survive, compound, and stay expectancy-positive after realistic friction.
- Win rate is not the main objective. Positive expectancy, controllable drawdown, and repeatability are.
- Prefer setups that can trade multiple times per day, but never sacrifice robustness just to force turnover.

## Capital Doctrine

- Capital survival comes before raw return.
- The default hard-loss budget is `3%` of equity at the daily or portfolio layer unless the CEO explicitly approves a different interpretation.
- Multi-trade strategies should normally risk a fraction of that budget per trade. `3%` per trade is not the default.
- Position sizing should scale from current equity so that valid strategies can compound without bypassing risk caps.
- Every serious candidate should define its stop model, expected reward model, and sizing model in `R` terms or with an equivalent expectancy explanation.
- Small-capital deployment is only valid when broker lot granularity and contract size still allow sane risk expression. A strategy that cannot size safely on `100 USD` is not micro-cap deployable on that broker.

## Promotion Philosophy

- Promote on actual MT5 evidence, not on a single optimization peak or Python-only results.
- A strategy is not `good` because it wins often. A strategy is good if:
  - expectancy stays positive after spread and slippage,
  - drawdown stays survivable,
  - trade count is large enough for the claimed edge to be meaningful,
  - the edge survives across regimes and forward review.
- If a family misses the active business objective, park it explicitly and open a cleaner research branch.
- If a family misses the active business objective across three serious cycles, do not keep retuning by default. Run a plateau review and either park, kill, or replace it.

## Default Risk Standards

- Daily hard-loss cap: `3%` equity.
- Portfolio or peak-to-valley kill-switch: required for demo or live candidates.
- Per-trade risk: small enough that an ordinary losing streak does not threaten continuation.
- Reward model: target roughly `1.2R` to `1.5R` average payoff or an equally clear expectancy edge after costs.

## Research Order

- Mine bar data and session behavior before writing large parameter grids.
- Keep high-turnover and low-turnover families separate.
- Prefer a small number of clear hypotheses over a large number of overlapping tweaks.
- Record rejected ideas as durable knowledge so future families do not repeat the same mistakes.

## Validation Ladder

- Search window: short enough to iterate, long enough to contain varied conditions.
- Locked validation window: long-window actual MT5 evidence is mandatory.
- Out-of-sample window: explicit and separate from the tuning window.
- Default rolling split for iterative development: latest `12 months`, with `9 months` for train / tuning and latest `3 months` as the forward-style OOS check.
- Promotion gate:
  - compile cleanly,
  - pass QA and risk checklists,
  - show positive expectancy after realistic friction,
  - show enough trades for the target operating style,
  - show broker lot-floor viability for the intended starting capital,
  - complete demo-forward review before live promotion.

## Plateau Discipline

- Every serious family should be reviewed for plateau after each serious cycle.
- Quality-positive but objective-negative families should become `secondary` or `parked`.
- The repo should open a new family quickly once plateau is confirmed, instead of stretching one family forever.
