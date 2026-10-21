# Context / exit research: incomplete batch review

## Status

The batch `20261006_214236_66a0b587` stopped at annual 2022. Five runs covering 2023–2026 passed execution checks: **181 entries / 905 exit-shadow rows**. 2018–2021 were not executed. Failed 2022 is excluded from the [verified partial outputs](runs/20261006_214236_66a0b587/verified_partial/scope.json).

2022 has 76 entries. One trade differs in volume (0.40 versus 0.41), profit (-61.62 versus -63.16), and net. Its entry on 2022-09-20 13:00 and exit on 2022-09-20 14:35:12, prices, SL and TP match. Prior accumulated swap differs, but that alone has not been proven to explain the lot-step crossing. Do not accept the run as fully equivalent or silently remove the trade.

A separate 2022 control runs the baseline without the research observer, using the current tester context. This distinguishes observer effects from environment drift and also checks the losslessly refactored EA. See [control manifest](../q12_refactor_check_20261006/manifest.json).

## Interim annual comparison

Same executed entries; price-based shadow R, not account net profit.

| Year | Entries | Fixed 22 pips / RR1.5 mean R | PF | H1 structure low / RR1.5 mean R | PF |
|---|---:|---:|---:|---:|---:|
| 2023 | 73 | -0.1580 | 0.708 | -0.0037 | 0.982 |
| 2024 | 23 | -0.2138 | 0.552 | -0.1445 | 0.441 |
| 2025 | 68 | +0.1717 | 1.411 | +0.1309 | 1.776 |
| 2026 | 17 | -0.0230 | 0.932 | +0.0698 | 2.087 |

H1 stop median distance is roughly 68–73 pips, versus the fixed 22 pips. A higher PF alone is not proof of a better policy: risk units, exposure and holding interactions differ. H1 stops do not make every observed year positive; 2024 remains negative. 2026 has only 17 entries.

## Limits and next decision

- 2023–2025 have mixed historical tick quality; 2026 clean-log runs are separate evidence. All periods are previously observed, not OOS.
- M15 execution is unchanged. M15/H1/H4 environments are diagnostic only.
- Shadows use Bid M1 paths after actual Ask entry, up to 18 M15 bars. Spread is reflected; commission and swap are not. Intraminute gap execution is approximate.
- Same-minute SL/TP ambiguity is excluded; unresolved end cases are separate. MFE/MAE cover the fixed horizon, not only the shadow trade lifetime.
- Different exits can change later position availability. This is not a full one-position counterfactual replay.
- No environment-dependent policy is adopted. Complete the identity investigation before interpreting the missing years or defining a subsequent fixed policy test.
