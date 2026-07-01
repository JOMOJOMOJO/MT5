# Session Reversal Dow-Fractal H1/M30/M5 Optimization Notes

## Objective

Test whether a generic Dow/fractal structure can support a multi-currency FX basket EA:

- H1 as upper trend/range context.
- M30 as structure wave3 or trend-bias layer.
- M5 as lower timeframe first-pullback/retest entry.

## Tested Adjustments

1. Hard ordered Dow H1/M30/M5 wave3 alignment.
2. Softened M30 structure: allow trend bias when no confirmed wave3 is available.
3. Require retest candle close beyond neckline.
4. Add break-even at 1.1R.
5. Require previous closed bar to break neckline before the current bar can be used as the retest.
6. Run the final concept-correct logic over full-year 2025.

## Key Results

| cycle | period | trades | PF | avg_R | net |
|---|---:|---:|---:|---:|---:|
| c1_full_hard_wave3 | 2025 full year | 163 | 0.844 | -0.0686 | -272.88 |
| c3_q1_retest_reclaim | 2025 Q1 | 99 | 0.977 | -0.0128 | -25.59 |
| c4_q1_be_1_1r | 2025 Q1 | 99 | 0.914 | -0.0426 | -93.88 |
| c6_full_cycle5_final | 2025 full year | 285 | 0.788 | -0.1046 | -700.13 |

## Rejected Options

- Break-even at 1.1R: rejected. It did not reduce full SL and worsened expectancy.
- Promoting London-only: rejected. London was positive, but sample/session dependence is not acceptable for the current objective.
- Symbol exclusion: rejected. USDJPY looked better in some runs, but the objective is a basket strategy and symbol filtering would be a repair by exclusion.
- Direction-only repair: rejected. Final full-year long and short were both negative.
- Fine tuning neckline/ATR thresholds: rejected at this stage because the core failure is structural.

## Durable Lesson

The current H1/M30/M5 Dow-fractal implementation can produce enough trades, but a neckline retest label alone is not enough to define a positive-expectancy first pullback. The failure mode is not a lack of trade count. It is poor post-breakout acceptance: too many retests fail directly into full SL.

Before optimizing thresholds, the next research family needs a stronger acceptance/retest-quality definition.

