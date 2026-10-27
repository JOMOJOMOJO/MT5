# lifecycle_harness: MQL5決定論テスト

実際のMT5内でエンジンを呼び出し、因果順序とLONG/SHORT分岐を確認する合成入力 96項目。PASS 96 / FAIL 0 / UNAVAILABLE 0。未取得をPASSへ算入しない。市場の売買事例とは区別する。

原本: [harness.csv](harness.csv)。

| テスト | 判定 | 詳細 |
|---|---|---|
| samebar_preknown_PERIOD_M15_PERIOD_M5_LONG | PASS | The W2-bound countertrend exists before the first continuation candle opens |
| first_progress_samebar_signal_PERIOD_M15_PERIOD_M5_LONG | PASS | The first closed W1 continuation may itself emit the valid initial reversal signal |
| samebar_progress_in_signal_snapshot_PERIOD_M15_PERIOD_M5_LONG | PASS | Progress timestamps are present in SIGNAL; the accepted trade is not invalidated |
| missed_initial_move_PERIOD_M15_PERIOD_M5_LONG | PASS | No pre-known countertrend at first closed continuation terminates this W1/W2 candidate |
| missed_move_timestamps_PERIOD_M15_PERIOD_M5_LONG | PASS | Source candle |
| missed_move_never_reused_PERIOD_M15_PERIOD_M5_LONG | PASS | Later local pivots cannot resurrect the expired W1/W2 setup |
| extension_before_fib_allowed_PERIOD_M15_PERIOD_M5_LONG | PASS | Fixed-W1 extension without an earlier Fib touch is not treated as a missed third-wave move |
| equal_close_and_wick_allowed_PERIOD_M15_PERIOD_M5_LONG | PASS | A wick beyond W1 and a close exactly at W1 do not expire the setup |
| wick_only_allowed_PERIOD_M15_PERIOD_M5_LONG | PASS | Only a strictly beyond-W1 closed price counts as continuation |
| samebar_first_fib_not_prior_PERIOD_M15_PERIOD_M5_LONG | PASS | OHLC cannot establish whether the first Fib touch preceded this same candle's extension |
| nextbar_after_fib_expires_PERIOD_M15_PERIOD_M5_LONG | PASS | The following continuation candle does have an earlier closed Fib observation |
| later_local_countertrend_rejected_PERIOD_M15_PERIOD_M5_LONG | PASS | Local LH/LL or HH/HL above/below the true deepest W2 is measured once and cannot trigger |
| rejected_structure_has_prices_PERIOD_M15_PERIOD_M5_LONG | PASS | Rejected countertrend anchors remain available for explaining the membership mismatch |
| legacy_membership_control_PERIOD_M15_PERIOD_M5_LONG | PASS | Explicit legacy policy reproduces the formerly accepted unrelated local reversal |
| equal_w2_retest_binding_PERIOD_M15_PERIOD_M5_LONG | PASS | A later equal-price extreme may bind the countertrend; first-W2 and binding times remain distinct |
| equal_w2_retest_signal_PERIOD_M15_PERIOD_M5_LONG | PASS | Time equality is not required for a genuine equal-price W2 retest reversal |
| new_w2_extreme_clears_old_trigger_PERIOD_M15_PERIOD_M5_LONG | PASS | A candle that changes W2 and crosses the old return level cannot use the stale structure |
| historical_progress_expires_now_PERIOD_M15_PERIOD_M5_LONG | PASS | Previously closed progress discovered at W1 confirmation is recorded at current availability time |
| historical_progress_never_signals_PERIOD_M15_PERIOD_M5_LONG | PASS | No replayed bar produces a past SIGNAL or a backdated invalidation |
| fib_disabled_prior_pullback_PERIOD_M15_PERIOD_M5_LONG | PASS | Fib-disabled research still expires after a previously observed positive retracement |
| strict_policy_default_behavior_PERIOD_M15_PERIOD_M5_LONG | PASS | Strict lifecycle closes the unentered initial move |
| legacy_expiry_control_PERIOD_M15_PERIOD_M5_LONG | PASS | Explicit legacy policy preserves the old indefinitely reusable candidate for comparison |
| existing_signal_not_expired_PERIOD_M15_PERIOD_M5_LONG | PASS | Lifecycle correction changes unentered candidates only; original signal and risk anchors remain fixed |
| open_position_not_expired_PERIOD_M15_PERIOD_M5_LONG | PASS | Lifecycle correction changes unentered candidates only; original signal and risk anchors remain fixed |
| samebar_preknown_PERIOD_M15_PERIOD_M5_SHORT | PASS | The W2-bound countertrend exists before the first continuation candle opens |
| first_progress_samebar_signal_PERIOD_M15_PERIOD_M5_SHORT | PASS | The first closed W1 continuation may itself emit the valid initial reversal signal |
| samebar_progress_in_signal_snapshot_PERIOD_M15_PERIOD_M5_SHORT | PASS | Progress timestamps are present in SIGNAL; the accepted trade is not invalidated |
| missed_initial_move_PERIOD_M15_PERIOD_M5_SHORT | PASS | No pre-known countertrend at first closed continuation terminates this W1/W2 candidate |
| missed_move_timestamps_PERIOD_M15_PERIOD_M5_SHORT | PASS | Source candle |
| missed_move_never_reused_PERIOD_M15_PERIOD_M5_SHORT | PASS | Later local pivots cannot resurrect the expired W1/W2 setup |
| extension_before_fib_allowed_PERIOD_M15_PERIOD_M5_SHORT | PASS | Fixed-W1 extension without an earlier Fib touch is not treated as a missed third-wave move |
| equal_close_and_wick_allowed_PERIOD_M15_PERIOD_M5_SHORT | PASS | A wick beyond W1 and a close exactly at W1 do not expire the setup |
| wick_only_allowed_PERIOD_M15_PERIOD_M5_SHORT | PASS | Only a strictly beyond-W1 closed price counts as continuation |
| samebar_first_fib_not_prior_PERIOD_M15_PERIOD_M5_SHORT | PASS | OHLC cannot establish whether the first Fib touch preceded this same candle's extension |
| nextbar_after_fib_expires_PERIOD_M15_PERIOD_M5_SHORT | PASS | The following continuation candle does have an earlier closed Fib observation |
| later_local_countertrend_rejected_PERIOD_M15_PERIOD_M5_SHORT | PASS | Local LH/LL or HH/HL above/below the true deepest W2 is measured once and cannot trigger |
| rejected_structure_has_prices_PERIOD_M15_PERIOD_M5_SHORT | PASS | Rejected countertrend anchors remain available for explaining the membership mismatch |
| legacy_membership_control_PERIOD_M15_PERIOD_M5_SHORT | PASS | Explicit legacy policy reproduces the formerly accepted unrelated local reversal |
| equal_w2_retest_binding_PERIOD_M15_PERIOD_M5_SHORT | PASS | A later equal-price extreme may bind the countertrend; first-W2 and binding times remain distinct |
| equal_w2_retest_signal_PERIOD_M15_PERIOD_M5_SHORT | PASS | Time equality is not required for a genuine equal-price W2 retest reversal |
| new_w2_extreme_clears_old_trigger_PERIOD_M15_PERIOD_M5_SHORT | PASS | A candle that changes W2 and crosses the old return level cannot use the stale structure |
| historical_progress_expires_now_PERIOD_M15_PERIOD_M5_SHORT | PASS | Previously closed progress discovered at W1 confirmation is recorded at current availability time |
| historical_progress_never_signals_PERIOD_M15_PERIOD_M5_SHORT | PASS | No replayed bar produces a past SIGNAL or a backdated invalidation |
| fib_disabled_prior_pullback_PERIOD_M15_PERIOD_M5_SHORT | PASS | Fib-disabled research still expires after a previously observed positive retracement |
| strict_policy_default_behavior_PERIOD_M15_PERIOD_M5_SHORT | PASS | Strict lifecycle closes the unentered initial move |
| legacy_expiry_control_PERIOD_M15_PERIOD_M5_SHORT | PASS | Explicit legacy policy preserves the old indefinitely reusable candidate for comparison |
| existing_signal_not_expired_PERIOD_M15_PERIOD_M5_SHORT | PASS | Lifecycle correction changes unentered candidates only; original signal and risk anchors remain fixed |
| open_position_not_expired_PERIOD_M15_PERIOD_M5_SHORT | PASS | Lifecycle correction changes unentered candidates only; original signal and risk anchors remain fixed |
| samebar_preknown_PERIOD_M5_PERIOD_M1_LONG | PASS | The W2-bound countertrend exists before the first continuation candle opens |
| first_progress_samebar_signal_PERIOD_M5_PERIOD_M1_LONG | PASS | The first closed W1 continuation may itself emit the valid initial reversal signal |
| samebar_progress_in_signal_snapshot_PERIOD_M5_PERIOD_M1_LONG | PASS | Progress timestamps are present in SIGNAL; the accepted trade is not invalidated |
| missed_initial_move_PERIOD_M5_PERIOD_M1_LONG | PASS | No pre-known countertrend at first closed continuation terminates this W1/W2 candidate |
| missed_move_timestamps_PERIOD_M5_PERIOD_M1_LONG | PASS | Source candle |
| missed_move_never_reused_PERIOD_M5_PERIOD_M1_LONG | PASS | Later local pivots cannot resurrect the expired W1/W2 setup |
| extension_before_fib_allowed_PERIOD_M5_PERIOD_M1_LONG | PASS | Fixed-W1 extension without an earlier Fib touch is not treated as a missed third-wave move |
| equal_close_and_wick_allowed_PERIOD_M5_PERIOD_M1_LONG | PASS | A wick beyond W1 and a close exactly at W1 do not expire the setup |
| wick_only_allowed_PERIOD_M5_PERIOD_M1_LONG | PASS | Only a strictly beyond-W1 closed price counts as continuation |
| samebar_first_fib_not_prior_PERIOD_M5_PERIOD_M1_LONG | PASS | OHLC cannot establish whether the first Fib touch preceded this same candle's extension |
| nextbar_after_fib_expires_PERIOD_M5_PERIOD_M1_LONG | PASS | The following continuation candle does have an earlier closed Fib observation |
| later_local_countertrend_rejected_PERIOD_M5_PERIOD_M1_LONG | PASS | Local LH/LL or HH/HL above/below the true deepest W2 is measured once and cannot trigger |
| rejected_structure_has_prices_PERIOD_M5_PERIOD_M1_LONG | PASS | Rejected countertrend anchors remain available for explaining the membership mismatch |
| legacy_membership_control_PERIOD_M5_PERIOD_M1_LONG | PASS | Explicit legacy policy reproduces the formerly accepted unrelated local reversal |
| equal_w2_retest_binding_PERIOD_M5_PERIOD_M1_LONG | PASS | A later equal-price extreme may bind the countertrend; first-W2 and binding times remain distinct |
| equal_w2_retest_signal_PERIOD_M5_PERIOD_M1_LONG | PASS | Time equality is not required for a genuine equal-price W2 retest reversal |
| new_w2_extreme_clears_old_trigger_PERIOD_M5_PERIOD_M1_LONG | PASS | A candle that changes W2 and crosses the old return level cannot use the stale structure |
| historical_progress_expires_now_PERIOD_M5_PERIOD_M1_LONG | PASS | Previously closed progress discovered at W1 confirmation is recorded at current availability time |
| historical_progress_never_signals_PERIOD_M5_PERIOD_M1_LONG | PASS | No replayed bar produces a past SIGNAL or a backdated invalidation |
| fib_disabled_prior_pullback_PERIOD_M5_PERIOD_M1_LONG | PASS | Fib-disabled research still expires after a previously observed positive retracement |
| strict_policy_default_behavior_PERIOD_M5_PERIOD_M1_LONG | PASS | Strict lifecycle closes the unentered initial move |
| legacy_expiry_control_PERIOD_M5_PERIOD_M1_LONG | PASS | Explicit legacy policy preserves the old indefinitely reusable candidate for comparison |
| existing_signal_not_expired_PERIOD_M5_PERIOD_M1_LONG | PASS | Lifecycle correction changes unentered candidates only; original signal and risk anchors remain fixed |
| open_position_not_expired_PERIOD_M5_PERIOD_M1_LONG | PASS | Lifecycle correction changes unentered candidates only; original signal and risk anchors remain fixed |
| samebar_preknown_PERIOD_M5_PERIOD_M1_SHORT | PASS | The W2-bound countertrend exists before the first continuation candle opens |
| first_progress_samebar_signal_PERIOD_M5_PERIOD_M1_SHORT | PASS | The first closed W1 continuation may itself emit the valid initial reversal signal |
| samebar_progress_in_signal_snapshot_PERIOD_M5_PERIOD_M1_SHORT | PASS | Progress timestamps are present in SIGNAL; the accepted trade is not invalidated |
| missed_initial_move_PERIOD_M5_PERIOD_M1_SHORT | PASS | No pre-known countertrend at first closed continuation terminates this W1/W2 candidate |
| missed_move_timestamps_PERIOD_M5_PERIOD_M1_SHORT | PASS | Source candle |
| missed_move_never_reused_PERIOD_M5_PERIOD_M1_SHORT | PASS | Later local pivots cannot resurrect the expired W1/W2 setup |
| extension_before_fib_allowed_PERIOD_M5_PERIOD_M1_SHORT | PASS | Fixed-W1 extension without an earlier Fib touch is not treated as a missed third-wave move |
| equal_close_and_wick_allowed_PERIOD_M5_PERIOD_M1_SHORT | PASS | A wick beyond W1 and a close exactly at W1 do not expire the setup |
| wick_only_allowed_PERIOD_M5_PERIOD_M1_SHORT | PASS | Only a strictly beyond-W1 closed price counts as continuation |
| samebar_first_fib_not_prior_PERIOD_M5_PERIOD_M1_SHORT | PASS | OHLC cannot establish whether the first Fib touch preceded this same candle's extension |
| nextbar_after_fib_expires_PERIOD_M5_PERIOD_M1_SHORT | PASS | The following continuation candle does have an earlier closed Fib observation |
| later_local_countertrend_rejected_PERIOD_M5_PERIOD_M1_SHORT | PASS | Local LH/LL or HH/HL above/below the true deepest W2 is measured once and cannot trigger |
| rejected_structure_has_prices_PERIOD_M5_PERIOD_M1_SHORT | PASS | Rejected countertrend anchors remain available for explaining the membership mismatch |
| legacy_membership_control_PERIOD_M5_PERIOD_M1_SHORT | PASS | Explicit legacy policy reproduces the formerly accepted unrelated local reversal |
| equal_w2_retest_binding_PERIOD_M5_PERIOD_M1_SHORT | PASS | A later equal-price extreme may bind the countertrend; first-W2 and binding times remain distinct |
| equal_w2_retest_signal_PERIOD_M5_PERIOD_M1_SHORT | PASS | Time equality is not required for a genuine equal-price W2 retest reversal |
| new_w2_extreme_clears_old_trigger_PERIOD_M5_PERIOD_M1_SHORT | PASS | A candle that changes W2 and crosses the old return level cannot use the stale structure |
| historical_progress_expires_now_PERIOD_M5_PERIOD_M1_SHORT | PASS | Previously closed progress discovered at W1 confirmation is recorded at current availability time |
| historical_progress_never_signals_PERIOD_M5_PERIOD_M1_SHORT | PASS | No replayed bar produces a past SIGNAL or a backdated invalidation |
| fib_disabled_prior_pullback_PERIOD_M5_PERIOD_M1_SHORT | PASS | Fib-disabled research still expires after a previously observed positive retracement |
| strict_policy_default_behavior_PERIOD_M5_PERIOD_M1_SHORT | PASS | Strict lifecycle closes the unentered initial move |
| legacy_expiry_control_PERIOD_M5_PERIOD_M1_SHORT | PASS | Explicit legacy policy preserves the old indefinitely reusable candidate for comparison |
| existing_signal_not_expired_PERIOD_M5_PERIOD_M1_SHORT | PASS | Lifecycle correction changes unentered candidates only; original signal and risk anchors remain fixed |
| open_position_not_expired_PERIOD_M5_PERIOD_M1_SHORT | PASS | Lifecycle correction changes unentered candidates only; original signal and risk anchors remain fixed |
