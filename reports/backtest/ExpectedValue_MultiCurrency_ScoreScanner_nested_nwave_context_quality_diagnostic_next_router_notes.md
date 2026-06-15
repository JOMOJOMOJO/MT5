# Nested N-Wave Context Quality Notes

This is a design seed, not implemented routing logic.

## Desired Classification

M15 neckline break -> Breakout Candle Quality -> Context Quality -> route.

| Breakout | Context | Diagnostic route hypothesis |
|---|---|---|
| strong | clean_context | instant entry |
| weak | clean_context | instant entry or shallow retest |
| weak | mixed_context | retest confirmation |
| dirty | clean_context | do not discard; retest/reclaim candidate |
| dirty | poor_context | skip |
| strong | poor_context | avoid chase; retest or skip |

## Context Inputs To Add To EA Diagnostics

- H4 wave-2 endpoint naturalness.
- H1 counter N-wave break quality.
- M15 pre-break extension.
- Obstacle-free room from neckline to 2R.
- Neckline age and excessive touch count.
- SL ATR width.
- 1R to 2R continuation room.

## Guardrail

The next implementation should first emit Context Quality labels and summary counters. It should not immediately route trades based on these labels.
