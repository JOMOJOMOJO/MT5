# Model freeze versus engineering rerun boundary

The model was selected and frozen using January-April only, before reading
May/June P/L. Its JSON SHA-256 has remained:

`cbd3dcbb9ce9c20319f4e06ed2666d87180f268e6fa63ab706b7b653a5569a63`

The first engineering build omitted the snapshot-to-candidate callback. During
that run the already-frozen model was evaluated on the May/June collected CSVs.
Monitoring then identified the missing callback, and that run was cancelled and
recorded invalid. The callback was restored, without changing model weights,
threshold, geometry, features or trade management. A training-day production
integration smoke was added before this r2 run.

Consequently `pre_holdout_artifact_hashes.csv` in THIS directory means **before
the r2 MT5 runs**, not before the first-ever reading of holdout outcomes. The
original model-freeze evidence and the first build's pre-run hashes are retained
in their original directories. Do not describe the repaired implementation as
untouched since before the first holdout CSV read. The model/strategy remained
untouched; the engineering connection changed for the documented reason.

No second candidate or alternative cutoff was selected after seeing May/June.
