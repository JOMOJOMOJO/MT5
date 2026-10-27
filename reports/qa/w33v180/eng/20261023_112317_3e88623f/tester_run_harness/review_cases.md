# tester_run_harness: MQL5決定論テスト

実際のMT5内でエンジンを呼び出し、因果順序とLONG/SHORT分岐を確認する合成入力 38項目。PASS 38 / FAIL 0 / UNAVAILABLE 0。未取得をPASSへ算入しない。市場の売買事例とは区別する。

原本: [harness.csv](harness.csv)。

| テスト | 判定 | 詳細 |
|---|---|---|
| context_t0_o0_allow0 | PASS | Batch permission can enable tester optimization |
| context_t0_o0_allow1 | PASS | Batch permission can enable tester optimization |
| context_t0_o1_allow0 | PASS | Batch permission can enable tester optimization |
| context_t0_o1_allow1 | PASS | Batch permission can enable tester optimization |
| context_t1_o0_allow0 | PASS | Batch permission can enable tester optimization |
| context_t1_o0_allow1 | PASS | Batch permission can enable tester optimization |
| context_t1_o1_allow0 | PASS | Batch permission can enable tester optimization |
| context_t1_o1_allow1 | PASS | Batch permission can enable tester optimization |
| ordinary_token_preserved | PASS | Ordinary run identifiers stay recognizable |
| unsafe_path_characters_removed | PASS | No slash |
| token_length_bounded | PASS | Long requested tags cannot exceed the configured component bound |
| empty_token_has_safe_fallback | PASS | An empty component receives a usable filename fallback |
| nonpositive_bound_empty | PASS | A nonpositive component bound produces no characters |
| trailing_dots_spaces_removed | PASS | Windows-normalized trailing dots and spaces do not survive |
| reserved_device_0 | PASS | Windows reserved device names receive a safe prefix |
| reserved_device_1 | PASS | Windows reserved device names receive a safe prefix |
| reserved_device_2 | PASS | Windows reserved device names receive a safe prefix |
| reserved_device_3 | PASS | Windows reserved device names receive a safe prefix |
| reserved_device_with_extension | PASS | A device name remains reserved before a filename extension; a suffix alone cannot make it safe |
| first_reservation | PASS | The first pass obtains a bounded tag and a held exclusive claim |
| symbol_identity_in_tag | PASS | The resolved name identifies this test request and its symbol |
| held_claim_is_exclusive | PASS | An unrelated reader cannot open the non-shared held claim |
| already_held_handle_not_replaced | PASS | A repeated call with a live handle cannot leak it or silently replace its namespace |
| simultaneous_same_context_distinct | PASS | Two identical contexts held simultaneously receive different output namespaces |
| reservation_does_not_create_events | PASS | Durable occupancy is independent of creating any CSV output |
| release_invalidates_handle | PASS | Release makes the caller's handle explicitly invalid |
| released_marker_remains_nonempty | PASS | A durable marker remains after release and has not been truncated |
| release_is_idempotent | PASS | Repeated cleanup of an invalid handle is harmless |
| released_namespace_never_reused | PASS | A completed pass's marker continues blocking reuse even though it has no CSV file |
| preexisting_events_fixture_created | PASS | The legacy-output fixture uses only this new harness-owned prefix |
| preexisting_events_namespace_skipped | PASS | A pre-existing events CSV without a prior claim cannot be selected for truncation |
| preexisting_events_contents_preserved | PASS | Reservation leaves the exact existing event contents unchanged |
| different_symbol_is_separate | PASS | Different Market Watch symbols cannot share CSV identities |
| different_context_is_separate | PASS | Different pass contexts retain distinct namespaces |
| all_resolved_paths_bounded | PASS | All reservation paths stay within the documented 70-character tag bound |
| all_reservations_pairwise_distinct | PASS | Every fixture namespace remains distinct across held and released claims |
| all_handles_released | PASS | The test releases every claim it acquired |
| all_durable_markers_reopen_after_cleanup | PASS | All retained markers can be read after cleanup |
