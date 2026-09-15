# Invalid engineering attempt — do not use as holdout performance

2026-09-11: the archived research source predates the candidate snapshot callback.
The private source tree contained TSTCOnSnapshot's definition, but TSTDArm did not
call it. Model-only parity passed all 11,230 training vectors but did not cover
this wiring. Candidate signal output remained empty while research ran.

The task-owned automation worker was stopped and its task-owned terminal was
asked to close normally. No result from this attempt is a strategy verdict.
Existing files and executed_EA.ex5 are retained; June was not run by this worker.

Repair: add the already-established three-line TS_TECH_CANDIDATE callback from
the tracked HEAD TechnicalStudy to the private archived copy. Do not restore
the user's deleted original file. No model, feature, threshold, geometry or
selection change. Frozen JSON SHA remains
cbd3dcbb9ce9c20319f4e06ed2666d87180f268e6fa63ab706b7b653a5569a63.

The r2 run must include a January integration smoke that reconciles nonzero
research snapshots to candidate signal rows before May/June begin.
May/June CSV replay had already been evaluated with the frozen model when the
wiring omission was discovered. This implementation repair was not selected
using those outcomes; no weights or trading parameters were changed.
