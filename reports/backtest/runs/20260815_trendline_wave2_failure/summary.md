# TRENDLINE_WAVE2_FAILURE Initial MT5 Validation

## Locked test

- Tester: MT5 Strategy Tester, M15 chart, Every tick based on real ticks (Model=4).
- Internal timeframes: H4 context / H1 setup / M15 entry; six FX symbols.
- Deposit: USD 10,000; leverage 1:100; fixed research parameters, no optimization.
- 2026 lock: `2026-08-15T21:36:50.4184238+09:00`; source `CE1B4E8804F3FDCEF1D94D544850185C3DA80D6D787FCAE604A7F82B4E08FF40`; include `B1B63A46F7815233CFCDC27D8C70E6EB69F65420941A73FD3EF33F73A5C68C0B`.
- Requested OOS end was 2026-08-14; last processed tester timestamp was 2026-08-13 23:57:55.

## Baseline / new bucket / combined

| Year | Mode | Trades | Win rate | Net | PF | Net exp R | Max DD closed | MT5/custom match |
|---:|---|---:|---:|---:|---:|---:|---:|---|
| 2024 | baseline | 147 | 46.26% | -17.61 | 0.986 | +0.0033 | 330.79 | True |
| 2024 | new_bucket_only | 0 | 0.00% | +0.00 | 0.000 | +0.0000 | 0.00 | True |
| 2024 | combined | 147 | 46.26% | -17.49 | 0.986 | +0.0033 | 330.79 | True |
| 2025 | baseline | 173 | 43.35% | -545.96 | 0.686 | -0.1317 | 548.19 | True |
| 2025 | new_bucket_only | 0 | 0.00% | +0.00 | 0.000 | +0.0000 | 0.00 | True |
| 2025 | combined | 172 | 43.60% | -523.00 | 0.696 | -0.1266 | 525.23 | True |
| 2026 | baseline | 36 | 47.22% | +32.99 | 1.115 | +0.0320 | 92.66 | True |
| 2026 | new_bucket_only | 0 | 0.00% | +0.00 | 0.000 | +0.0000 | 0.00 | True |
| 2026 | combined | 36 | 47.22% | +32.99 | 1.115 | +0.0320 | 92.66 | True |

## New bucket funnel

| Year | H4 impulse | H1 mature | H1 TL break | M15 pullback | M15 failure | M15 break | Orders |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 2024 | 80 | 4 | 1 | 0 | 0 | 0 | 0 |
| 2025 | 48 | 3 | 2 | 2 | 0 | 0 | 0 |
| 2026 | 40 | 1 | 1 | 0 | 0 | 0 | 0 |

## Findings

- New-only and combined produced identical new-bucket funnels in every year; the independent state path is isolated from the legacy bucket.
- No new-bucket order was generated. The primary bottleneck is structural, before execution: H1 maturity is rare and no setup reached M15 continuation-failure classification.
- Because there were no new-bucket orders, lot rounding, post-fill 2R modification, portfolio caps, margin rejection and new-bucket deal reconciliation were compile/static-path checked but not exercised by a real new-bucket order.
- The combined 2025 legacy run had one fewer trade than baseline because `combined_same_direction_position_cap` rejected one candidate; 2024 and 2026 counts matched.
- Fixed 2R break-even win rate is 33.33% before costs. No new-bucket sample exists, so expectancy cannot be estimated.

## Decision

- This initial parameterization is not promotable. Keep it as a correctly instrumented research bucket and investigate the H4 invalidation / H1 maturity / M15 failure funnel one factor at a time without using 2026 as tuning data.
