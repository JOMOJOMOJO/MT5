# Research publication inventory

Base: `292e9494bb7332837c2c00d74244bae9da6bcda1`.
Branch: `research/tickshock/2026-09-13-two-stage-ml`.
Remote: `origin`, https://github.com/JOMOJOMOJO/MT5.git.

| Commit | Scope | Files |
|---|---|---:|
| e60d1ce8 | Technical ML / monthly collection / 4m2m evidence | 802 |
| b616a802 | Remaining development collection QA | 31 |
| f9057afb | Time exits and matched-trade diagnosis | 26 |
| d53fd562 | SL/TP grid implementation and evidence | 144 |

`inventory.csv` records pre-publication working-file SHA-256, size, action,
group and reason. `commit_plan.json` lists the exact paths in the four
commits. These inventory artifacts themselves are saved in a final separate
checkpoint commit (no recursive self-hash).

1003 research files were committed. Excluded files remain on disk without
deletion, restoration, or content changes. No blanket git add/clean/reset
was used. Two deleted old includes were not staged; historical Step 15G
binary/log/suite changes were not staged. Large (>2 MB) generated files,
duplicate replay, terminal reports/journals, runtime locks and status stay
local. This is a source and compact-evidence checkpoint, not a complete raw
dataset backup or a guarantee of a clean worktree.

Credential pattern scans (including numeric account/login fields) found no
matches among selected files. Python AST parsing passed for 14 selected
scripts. Each commit passed `git diff --cached --check`. The initial helper
invocation was blocked by PowerShell execution policy before any commit;
the index was regrouped without changing working files and the repository
helper was run using its documented ExecutionPolicy Bypass invocation.

No strategy changes, compile, backtest or model training were performed by
the publication operation. See the historical research reports for their
actual validation results; the losing strategies are not promoted.
