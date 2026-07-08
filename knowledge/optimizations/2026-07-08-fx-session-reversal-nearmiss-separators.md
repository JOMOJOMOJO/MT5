# FX Session Reversal Near-Miss Separator Outcome

## Hypothesis

The required-light M15 wave2 gate was profitable but too sparse. Instead of loosening it directly, test whether required-light rejects that later reached MFE >= 1R share pre-entry separator features.

## Tested Separators

- M5 invalidation candle quality
- No immediate close-back failure after break
- Retest rejection quality
- M5 corrective exhaustion
- M15 wave2 completion quality
- Target room
- 75SMA / Granville quality
- Best single and best two OR combinations

All separators used only information known before entry. MFE/result labels were used only in the analyzer.

## Full 2025 Outcome

| Candidate | Trades | PF | avg_R | Net |
| --- | ---: | ---: | ---: | ---: |
| baseline c10 | 318 | 0.59 | -0.1582 | -1144.89 |
| required-light | 50 | 1.34 | +0.1099 | +134.29 |
| invalidation quality | 187 | 0.70 | -0.1093 | -470.18 |
| no-immediate-failure | 181 | 0.75 | -0.0829 | -345.84 |
| retest quality | 177 | 0.71 | -0.1006 | -407.76 |
| corrective exhaustion | 244 | 0.84 | -0.0547 | -324.24 |
| M15 completion | 270 | 0.64 | -0.1393 | -872.48 |
| target room | 50 | 1.34 | +0.1099 | +134.29 |
| Granville quality | 268 | 0.61 | -0.1486 | -921.78 |
| best two mask 40 | 244 | 0.84 | -0.0547 | -324.24 |

## Lessons

- The profitable required-light slice did not become scalable with these separators.
- `targetroom` preserved expectancy but did not add trades; it was effectively the same 50-trade fragment.
- `corrective_exhaustion` reached 244 trades and improved over baseline, but expectancy stayed negative.
- The near-miss reject population was not separated cleanly by the tested M5 invalidation/retest/Granville buckets.
- Continue only if a new separator is structurally different; avoid further threshold tuning around these same buckets.

## Decision

No 2025 shallow gate pass. Do not proceed to 3-year fixed BT or OOS for this cycle.
