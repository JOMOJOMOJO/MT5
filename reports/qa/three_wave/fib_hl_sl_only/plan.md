# Frozen SL-only experiment

2026-09-25. Same 2025Q1 Fib50-61.8 closed entry, EMA OFF, reversal-10 initial SL, initial RR1.2, Equity1%, cooldown15min. Only difference from prior dynamic mode: InpRecalculateTPOnHL=false, preserving initial plan.tp while HL-10 tightens SL. Default true retains previous behavior. Production and Shared unchanged. Research binary rebuilt v1.01, compile0/0. Reuse archived static and SL+TP reference runs; independently audit unchanged candidate stream, source delta, initial-risk accounting, fixed TP and HL confirmation times. No threshold optimization. Prior period already viewed, not OOS.

Entry delay investigation uses archived hl_compare_q1_ready/confirm/retest (EMA ON, RR1), not a claim about a specific unprovided current chart. Those frozen presets use M1 right2. Separate code path from current Fib pre-HL entry. Report pivot bar opening time versus confirmation and decision/fill separately.
