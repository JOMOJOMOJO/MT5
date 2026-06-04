# Recommended Next Task

- task_name: ThirdWave Entry Timing v3 Wave-Position Diagnostic Branch
- reason: The strongest evidence says current ThirdWave is not entering third-wave initial positions. Wave Audit is dominated by `chasing_entry`; v2 reduced weak setups but did not change the core wave-position problem.
- expected_benefit: Improve average R and reduce late/chasing losses without escaping into XAUUSD-only or direction-only filtering.
- why_not_other_tasks: Regime filtering helps but still leaves late entries. Pullback filters already over-filtered in v2. SL/TP work would mask bad entries. Candidate ranking should wait until candidate quality is real.
- minimal_implementation: Add a separate research mode that keeps existing ThirdWave structure but gates final entry by wave-position quality: reclaim/breakdown proximity, bars since reclaim/breakdown, distance from pullback extreme, and pre-entry momentum exhaustion. Keep all values fixed from audit distributions, not optimized.
- validation_plan: First run the same short windows used for Wave Audit and v2: 2025-02, 2025-08, 2025-10, and 2026-Q1. Compare against current ThirdWave regime BOTH all-candidates 5m. If it improves PF or avg_R without over-filtering, run annual 2024, 2025, and 2026YTD.
- stop_condition: Discard if 2 of 3 annual windows do not improve PF or avg_R. Discard as generic logic if FX net does not improve. Discard if trade count falls more than 50% without clear PF/avg_R improvement. Discard as generic logic if improvement is only XAUUSD. Split or park if only LONG or only SHORT improves. Discard if `third_wave_initial` plus `third_wave_middle` share does not materially rise and `chasing_entry` remains dominant.
