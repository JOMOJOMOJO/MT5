# Git Branch Strategy

## Goal

- Keep `main` readable and deployable.
- Separate research, operations, and org changes so backtests, release work, and workflow changes do not blur together.
- Let Codex handle branch, commit, and push work consistently instead of relying on ad hoc git usage.

## Branch Types

- `main`
  - the shared trunk
  - keep this as the integration branch for accepted work
- `research/<family>/<date>-<slug>`
  - new hypotheses
  - EA logic changes
  - optimization and OOS work
- `ops/<family>/<date>-<slug>`
  - demo-forward
  - live-preflight
  - telemetry
  - release packet updates
- `org/<date>-<slug>`
  - company workflow
  - checklists
  - branch strategy
  - git automation
- `hotfix/<date>-<slug>`
  - urgent bug or regression fixes

## Default Rule

- If the change touches EA logic or backtests, start from `research/...`.
- If the change touches release, demo/live, or operator workflows, start from `ops/...`.
- If the change touches company structure, git rules, or shared workflow, start from `org/...`.
- If a task spans both logic and release, prefer one research branch first, then a small ops branch only if needed.

## Commit Style

- Prefer one logical change per commit.
- Use direct prefixes:
  - `research: ...`
  - `ops: ...`
  - `org: ...`
  - `risk: ...`
  - `live: ...`
  - `docs: ...`
- A commit message should answer:
  - what changed
  - why it was necessary

## Publish Rule

- Do not push random dirty state.
- Stage only the paths that belong to the current task.
- Push the current task branch to `origin`.
- Merge to `main` only after the branch state is coherent enough to explain in one review note or release note.

## Codex Operating Rule

- Codex is allowed to create task branches, commit task-scoped changes, and push them to `origin` when the user asks.
- For this repo, the default assumption is that Codex should manage the branch lifecycle instead of asking the user to type git commands manually.
- If the working tree already contains unrelated dirty files, Codex should avoid staging them and commit only the task-relevant paths.

## Repo Scripts

- Start a task branch:
  - `powershell -ExecutionPolicy Bypass -File scripts/git-start-task.ps1 -Category research -Family btcusd-20260330-session-meanrev -Slug oos-review`
- Publish a task branch:
  - `powershell -ExecutionPolicy Bypass -File scripts/git-publish-task.ps1 -CommitMessage "research: add recent OOS gate" -Paths reports/backtest/...,.company/qa/checklist.md`
