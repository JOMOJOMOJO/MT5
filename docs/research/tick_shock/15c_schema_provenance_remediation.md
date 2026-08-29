# Step 15C schema provenance remediation

## Resolution

`TS15A-PROV-001` was a lineage error in the test contract, not a reason to
rewrite the frozen Step 15A expected file or to mislabel current output.

- Historical Step 15A detector-feature artifacts remain
  `tickshock-detector-feature-v1`.
- Current Step 15B and later detector-feature output remains
  `tickshock-detector-feature-v2`.
- The v1 to v2 migration adds the `direction` column.
- All v1 columns retain their names and meanings.
- The frozen Step 15A detector specification hash remains
  `53DB75EEE4641D98F4917E74B9C26B84D07533CE8EA1A6689AF7F36BAAEA64EA`.

Production exposes separate historical and current schema identities plus an
explicit migration contract. `TS15A-PROV-001` now calls the historical
contract; it does not call the current writer identity. Current-v2 and
migration tests are separate production-path observations.

## Supersession rule

The old interpretation that one function must identify both a frozen artifact
and the current writer is superseded. The numerical expected values and their
hashes are unchanged. Future schema changes must add a new version, migration
record, and current contract without rewriting prior expected evidence.
