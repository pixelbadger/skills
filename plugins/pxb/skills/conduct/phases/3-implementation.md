# Phase 3: Implementation

## Dispatch

Each implementation stream and composition implementor is dispatched with `briefs/implementor.md`.

Each writing stream gets its own worktree, which you create before dispatch, from the locked base, outside the repository, under a short root (e.g. `/tmp/sw/<stream>` or `C:\sw\<stream>`; deep paths break `MAX_PATH`, socket paths and some build tools):

```text
git worktree add -b swarm/<stream> <short root>/<stream> <base SHA>
```

- If the repository references sibling checkouts by relative path (e.g. `../OtherRepo/...`), add a detached worktree of each as a sibling, at the commit the conductor's checkout uses: `git -C <repo> worktree add --detach <short root>/<OtherRepo> <SHA>`. Workers treat these as read-only. Remove them with the stream worktrees.
- Don't use agent-runtime automatic worktree isolation: it can branch from the wrong commit, and can delete the worktree when a worker pauses without changes.
- Workers never write in the conductor's checkout.
- Remove a stream's worktree and `swarm/*` branch once its composition is accepted.

## Ledger and spend

Keep the stream ledger in `streams.md`:

| Stream | Tier | Depends on | State | Commit | Concerns |
|---|---|---|---|---|---|

States: `blocked`, `running`, `ready` (returned, awaiting review), `accepted` (reviewed against its contract), `rejected`, `superseded`.

Keep the spend line in `run.md`, updated at each dispatch, e.g. `Spend: round 2 of 4 · 9 of 20 subagents · 1h40 of 4h`. List pre-lock dispatches (baseline, probes) as `pre-lock`, not counted against the budget ⚙. If the next dispatch would exceed any budget item, stop and ask the conductor, giving spend, what remains, and a recommendation.

## Review each return

- Inspect the diff against the stream's contract. Read its tests, not their names. Note assumptions and cross-stream concerns. Reject or re-dispatch on any violation of the locked spec.
- For a stream that changes what users see, run the early visual checkpoint (`reference/e2e-design.md` §5) before accepting it.
- A repeated report for an accepted stream is a duplicate. Before relying on that stream, confirm its branch head is unchanged and its worktree clean.

## Composition

Integrate only a coherent candidate containing every accepted stream, never piecemeal. Compose in a dedicated composition worktree. Conflict-free merges and fast-forwards are plumbing, so do them yourself. Anything needing content edits or conflict decisions goes to a composition implementor: you may specify the resolution, not apply it.

Once a coherent candidate is composed, set `Phase: integration` and read `phases/4-integration.md`.
