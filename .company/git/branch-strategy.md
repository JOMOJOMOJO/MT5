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

## Land Rule

- Default landing path:
  - work on `research/*`, `ops/*`, `org/*`, or `hotfix/*`
  - commit and push the task branch
  - if `main` is unprotected, land directly from the repo
  - if `main` rejects direct push, switch to PR automation
- Direct land helper:
  - `powershell -ExecutionPolicy Bypass -File scripts/git-land-task.ps1 -SourceBranch <task-branch> -TargetBranch main`
- If branch cleanup is desired after a successful land:
  - `powershell -ExecutionPolicy Bypass -File scripts/git-land-task.ps1 -SourceBranch <task-branch> -TargetBranch main -DeleteLocalSource -DeleteRemoteSource`
- If the direct push to `main` fails, treat that as a signal that the branch is protected and use PR-based automation instead of retrying manual ad hoc commands.
- PR automation helper when `main` is protected:
  - `powershell -ExecutionPolicy Bypass -File scripts/git-open-pr.ps1 -HeadBranch <task-branch> -BaseBranch main -Title "<type>: <summary>"`
- If `gh` is unavailable on the machine, keep the branch pushed and stop at a clean task branch instead of forcing a manual half-landed state.

## Codex Operating Rule

- Codex is allowed to create task branches, commit task-scoped changes, and push them to `origin` when the user asks.
- For this repo, the default assumption is that Codex should manage the branch lifecycle instead of asking the user to type git commands manually.
- If the working tree already contains unrelated dirty files, Codex should avoid staging them and commit only the task-relevant paths.

## Repo Scripts

- Start a task branch:
  - `powershell -ExecutionPolicy Bypass -File scripts/git-start-task.ps1 -Category research -Family btcusd-20260330-session-meanrev -Slug oos-review`
- Publish a task branch:
  - `powershell -ExecutionPolicy Bypass -File scripts/git-publish-task.ps1 -CommitMessage "research: add recent OOS gate" -Paths reports/backtest/...,.company/qa/checklist.md`
- Land a task branch into `main`:
  - `powershell -ExecutionPolicy Bypass -File scripts/git-land-task.ps1 -SourceBranch research/btcusd-mainline/2026-04-01-feature-lab -TargetBranch main`
- Open a PR when `main` is protected:
  - `powershell -ExecutionPolicy Bypass -File scripts/git-open-pr.ps1 -HeadBranch research/btcusd-mainline/2026-04-01-feature-lab -BaseBranch main -Title "research: add flow feature lab"`
