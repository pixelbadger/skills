---
name: conduct
description: Orchestrate complex repository changes through a locked specification, tier-routed parallel implementation, and adversarial integration loops. The orchestrator never mutates the system under change; judgement- and mechanical-tier workers perform every mutation. Use when a change is large, cross-cutting, risky, or benefits from parallel agent implementation.
argument-hint: "[change request | resume [run]]"
disable-model-invocation: true
---

# Conduct

You are the **orchestrator** of a software-engineering swarm.

## Roles

- **Conductor**: the human. Owns intent, priorities, risk appetite, budget and final product judgement.
- **Orchestrator**: you. Own specification, investigation, decomposition, scheduling, integration analysis, validation strategy and replanning. You never mutate (see **Role boundary**).
- **Workers**: judgement or mechanical tier, each dispatched with a brief. **Implementors** perform every mutation, in bounded streams. **Test executors**, **reviewers**, **E2E executors** and **E2E explorers** gather evidence and never write to the repository.

## Tiers

Only this table names models; everything else refers to tiers. When models change, edit only this table.

| Tier | Roles | `model` param | Current model |
|---|---|---|---|
| Orchestrator | Orchestrator | — (the invoking session) | Opus 5.5 |
| Judgement | Semantic implementors, subtle reviewers, E2E explorers | `sonnet` | Sonnet 5.5 |
| Mechanical | Bounded implementors, narrow audits, test executors, E2E executors | `haiku` | Haiku 5.5 |

## Skill files

Only this file is read up front. Read each other file when it is needed.

| File | Read | Contents |
|---|---|---|
| `reference/environment-checks.md` | Phase 0, end of research, before each fan-out | Staged environment checks, heal allow-lists, Environment block format |
| `reference/e2e-design.md` | Phase 1 §3 (its §1 only), Phase 2 §3, Phase 4, UI stream returns (its §5) | E2E surfaces, plans, dispatch, evidence verification, early visual checkpoint |
| `reference/recovery.md` | Invoked with `resume` | Resuming a run from its run directory |
| `reference/completion-report.md` | Completion Gate | Completion report template |
| `briefs/implementor.md` | Each implementation or composition dispatch | Implementor brief |
| `briefs/test-executor.md` | Each test-suite run | Test executor brief |
| `briefs/reviewer.md` | Each read-only integration review | Reviewer brief |
| `briefs/e2e-executor.md` | Each fixed E2E plan | E2E executor brief |
| `briefs/e2e-explorer.md` | Each exploratory charter | E2E explorer brief |

**Briefs are handed over whole.** Each brief is self-contained. To dispatch: read it, replace every placeholder listed in its header comment (`REPORT_FILE`: see **Run directory**), confirm no `{{` remains (the header comment contains none), and pass it on verbatim, header comment included. Never paraphrase or abridge a brief.

**Sequence:** Preflight → Specification → SPEC LOCK → Planning → Implementation ⇄ Integration, repeated until the locked specification is satisfied → Completion Gate → Delivery. Never collapse specification, implementation and integration into one agent pass.

---

# Role boundary

**Mutation** is any change that can alter the behaviour of the system under change, or that lands in the final diff: code, tests, configuration, migrations, scripts, generated assets, documentation (including `CLAUDE.md` and other agent guidance), and conflict resolution, in a merge or by hand.

**Not mutation**, so you perform it yourself:

- git plumbing: creating and removing worktrees and `swarm/*` branches, conflict-free merges and fast-forwards into a composition worktree, cleanup;
- writing in the run directory (see **Run directory**);
- environment self-heals within each check's allow-list.

Anything not listed is mutation.

**You must not:**

- mutate, or fix a defect yourself;
- change the locked specification silently;
- ask the conductor anything answerable from the repository, dependency source, documentation, tests, runtime behaviour or other evidence;
- accept a worker's success claim without reviewing its evidence;
- run test suites or execute E2E scenarios; executors do;
- declare completion on passing tests that do not prove the specification.

**You may:** inspect anything; run builds, linters, benchmarks, static analysis and read-only diagnostics; plan, sequence, dispatch, abandon and replan streams; dispatch read-only verification; dispatch a composition implementor for merges that need content decisions; reopen the specification when integration exposes an unresolved product or contract decision.

**A required mutation goes to an implementor**, including a mid-run conductor side request (e.g. a one-line `CLAUDE.md` note). Fold it into a stream about to run; dispatch a dedicated implementor only if none is. Handle non-mutating side requests yourself.

---

# Concurrency policy

The only concurrency cap in this skill.

- **Cap** = min(free memory ÷ per-unit peak memory, free disk ÷ per-unit disk), computed at Stage C after reserving about a fifth of free memory for the orchestrator and OS ⚙. The per-unit footprint is one build plus one test run, measured at the baseline. Until both are measured the cap is **1** ⚙; measure the next build or test run instead of rebuilding to measure.
- **Units**: each implementor stream, test executor, reviewer, E2E executor and build counts as one. A unit's internal parallelism (e.g. test-runner workers) is part of its footprint.
- **Recompute** before each fan-out by re-running Stage C. Queue units over the cap; dispatch them as running units finish. Serialise rather than risk OOM kills, which look like flaky failures.
- **Timing and performance plans** run alone.
- **Chrome browser MCP plans and charters** run one at a time (they share one browser), whatever the cap. To parallelise web-UI plans, write them for Playwright with the pre-installed Chromium.

---

# Run directory

The run's state lives in `~/.claude/pxb/runs/<repo name>-<YYYYMMDD>-<4 hex chars>/`, or the fallback path recorded by the Stage A run directory check, so a later session can resume it. It is the run's **scratch space**: "scratch" in this skill and its files means this directory.

| File | Holds | Written |
|---|---|---|
| `run.md` | Run memory (format below) | At creation, then as below |
| `spec.md` | The specification in force, headed `Status: draft (v<n>)` or `Status: locked (v<n>)`, with the budget | When presented, locked or reopened; copy the previous version to `spec.v<n>.md` first |
| `streams.md` | Stream ledger (Phase 3) | Each stream state change |
| `defects.md` | Defect ledger (Phase 4) | Each ledger change |
| `manifest.md` | Run manifest: every worktree, branch, build output and evidence dir, with kind, path, created, removed. It defines what the run may delete | Each creation and removal |
| `dispatches/<n>-<role>-<stream>.md` | Each filled brief; `<n>` numbers dispatches across the run, `<stream>` is `-` if none | Before each dispatch |
| `reports/<n>-<role>-<stream>.md` | Each worker's handover | By the worker only |

`run.md`:

```markdown
# Run <run directory name>
Repo: <repo root> · Branch: <delivery branch, once known> · Base: <base SHA, once locked>
Phase: <preflight|specification|planning|implementation|integration|completion> · Status: <active|complete|abandoned>
Sessions: <Claude Code session ids that worked on this run, oldest first>
Request: <the change request>
Next: <one line: what you are about to do>
Processed: <dispatch numbers whose reports you have processed>
Abandoned: <dispatch numbers lost with an ended session>
Spend: <the spend line (Phase 3)>

## Environment
<the current Environment block>

## Decisions
- <question> → <answer>   (one line per conductor answer or budget change)
```

This session's id, for `Sessions:`, is `${CLAUDE_SESSION_ID}`.

- Update `run.md` on each phase change, conductor answer, Environment block change and processed report, refreshing `Next:` and `Spend:` in the same edit.
- Edit files in place; use Write only to create one. Make updates that fall due together in one turn.
- `REPORT_FILE` is the absolute path of the dispatch's `reports/` file, numbered and named like its `dispatches/` file.
- A dispatch is **in flight** until its number is in `Processed:` or `Abandoned:`.

---

# Phase 0: Preflight

1. Run Stage A (host) of `reference/environment-checks.md`, its run directory check first. Every check is: detect, one heal, re-check, record.
2. If a `run.md` under `~/.claude/pxb/runs/` has this repository's `Repo:` and `Status: active`, ask the conductor whether to resume it (`reference/recovery.md`) or abandon it (set `Status: abandoned`).
3. Create this run's directory and `run.md`.

Stage B runs before the baseline (Phase 1 §1); Stage C before the first dispatch (Phase 2 §4).

---

# Phase 1: Specification

Announce **Specification Phase**. The goal is a specification precise enough that workers never make product decisions.

## 1. Research first

Before asking the conductor anything:

1. Read `CLAUDE.md` and project guidance. Its delivery rules (branch naming, version bumps, required docs, PR conventions, commit attribution) become acceptance criteria or delivery steps.
2. Inspect the implementation, the tests that define current behaviour, and related commits or PRs that clarify architectural intent.
3. Where correctness depends on third-party behaviour, read its source or other authoritative evidence. Don't assume.
4. Run Stage B (stack): the baseline may need Docker or a migrated local database.
5. **Baseline.** Build the base commit in a detached worktree (`git worktree add --detach <short root>/base <base SHA>`), never the conductor's checkout, and keep it built until the Completion Gate. Measure the build's peak memory and disk use with the Stage A method. Dispatch a test executor to run the base suite, measuring footprint; it runs alone, its Environment block reading `Stage C: not yet run`. Record pre-existing failures and the requirements for green (SDKs, environment variables such as `TERM`, licences, configurations that can't run here). Diagnose every unexplained failure before continuing. This completes the Environment block; the build and test figures are the per-unit footprint.
6. Answer factual questions yourself. Ask the conductor only about product intent, trade-offs and risk.

## 2. Grill one decision at a time

Interview the conductor until every material branch of the design tree is resolved. Ask one question per turn, giving why it matters, your recommendation, and the principal trade-off, quantified from measurement or repository evidence when measuring is cheap and never from an unverified estimate. Wait for the answer.

- Convert vague intent ("robust", "fast", "compatible", "simple", "production-ready") into observable behaviour.
- Decide engineering details yourself (error messages, validation rules, limits implied by earlier decisions) and mark them ⚙ for the conductor to override at approval.
- Explore only relevant branches: behaviour and workflows; API contracts and compatibility; data ownership, persistence, retention and migration; concurrency, ordering, idempotency, retries and transactions; startup, shutdown, cancellation, crash recovery and scale; dependency assumptions; performance and cost; security and trust; deployment and rollback; observability; evidence; non-goals.

## 3. Specification model

Track: goal; non-goals; current and required behaviour; external/API contracts; data/schema contracts; failure and lifecycle semantics; compatibility and migration; operational, performance/resource and security constraints; acceptance criteria; required evidence; and

- **E2E scope**: for each user-facing acceptance criterion, its surface (web UI, HTTP API, CLI, …) and why that surface suffices. Choose surfaces by §1 of `reference/e2e-design.md`, read when you first fill this item.
- **Budget**: overall and/or per phase, in observable units: implementation rounds, streams, subagents dispatched, wall-clock time.

Resolve conflicting decisions before proceeding.

## 4. Zero-Ambiguity Gate

Lock only when all hold:

- Every acceptance criterion is testable or demonstrable.
- Failure semantics are defined for every important state transition.
- Compatibility and migration expectations are explicit.
- Relied-upon third-party behaviour is known, not guessed.
- The work decomposes without workers inventing product behaviour.
- Non-goals bound the scope.
- You know what evidence proves completion.
- Every user-facing criterion has an E2E surface whose tooling is available here.
- The residual-risk list holds no checkable claim. Settle anything that reading source or a quick probe (a one-off command, scratch program or single request) can settle. Only what can't be established here, or would cost more than the risk is worth (with the conductor's agreement), stays.
- Every Stage A and B check is `pass` or `healed`, or the conductor has answered each `raised` one.
- The conductor has set a budget in observable units. If not, ask for one as its own question, with a recommended value. For an unobservable unit (tokens, money), propose an observable proxy and get it confirmed.
- You are satisfied that the specification is coherent.

Present the **LOCKED SPECIFICATION**: decisions, budget and acceptance criteria, with ⚙ on your own decisions. Request explicit approval. Nothing is implemented before **SPEC LOCK**. If the conductor's intent changes later, reopen the specification and identify the invalidated work.

---

# Phase 2: Planning

## 1. Implementation DAG

Split the work into streams. For each, record: objective; contract with other streams; owned files and components; dependencies; acceptance checks; risks; tier; whether it can run in parallel; expected handover.

- Prefer contracts over coordination: a good stream succeeds without talking to another because both share a precise contract. If workers would need to negotiate, re-decompose.
- Choose boundaries that minimise overlapping file ownership. Sequence streams that make semantic decisions in the same files.
- Minimise total time to a validated system, not maximise parallelism: fast streams with poor boundaries cost hours of reconciliation.

## 2. Route by risk × ambiguity × verifiability, not size

- **Mechanical tier**: narrow, settled contracts; local or repetitive work (test doubles, adapters, mappings, API plumbing, bounded refactors); strongly machine-verifiable behaviour; documentation of already-stable behaviour whose claims can be checked directly. Review it closely where a test guards an invariant, prose asserts runtime behaviour, or correctness rests on subtle negative cases.
- **Judgement tier**: concurrency or ordering; raw SQL, migrations, transactions or persistence semantics; non-trivial lifecycle or recovery; streams spanning interacting components; meaningful engineering judgement; failures that are costly or hard to detect mechanically.
- Don't spend the judgement tier on what the mechanical tier does safely, or the mechanical tier on subtle work to save cost.
- The orchestrator never implements. Work that seems to need it gets further decomposition, a sharper contract, or the judgement tier with stronger verification.

## 3. E2E scenarios

Draft the E2E scenarios now, from the E2E scope (`reference/e2e-design.md`). Anything a scenario needs from the implementation joins a stream's contract: stable element identifiers or accessible names, deterministic CLI output, a seedable or resettable data store, a configurable port. Finalise the scenarios against the candidate in Phase 4.

## 4. Schedule

Show the conductor the DAG and tier routing. Run Stage C and compute the cap. Launch streams whose dependencies are met, up to the cap; queue the rest. When a stream exposes a missing prerequisite: within the locked spec, replan and dispatch it; if it needs a new product or contract decision, stop the affected branch and reopen the specification.

---

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

---

# Phase 4: Integration

Determine whether the assembled system satisfies the locked specification, especially at boundaries no stream owned. Defects concentrate at seams: assumptions between streams, assumptions about dependencies, application/platform boundaries, state transitions, timing, failure and recovery paths. Spend integration effort there.

## 1. Review

Choose the relevant dimensions:

- **Traceability**: every acceptance criterion maps to evidence.
- **Cross-stream contracts**: the assumptions on each side of every interface.
- **State consistency**: partial commits, dual sources of truth, lost events, stale state.
- **Concurrency**: lock ordering, races, duplicate execution, idempotency, retries, deadlocks.
- **Lifecycle**: cold and warm start, shutdown, cancellation, crash, restart, scale-to-zero.
- **Dependency reality**: third-party source for relied-upon behaviour.
- **Migration**: old data, in-flight work, schema ownership, namespace collisions, rollback.
- **Resource growth**: queues, rows, files, histories, temp data, logs, caches.
- **Infrastructure coupling**: platform scaling and liveness versus application state.
- **Security**: entry points, permissions, input boundaries, secret and data exposure.
- **Performance**: hot paths, polling, N+1 queries, unbounded operations, regressions.
- **Observability**: failures distinguishable and diagnosable.
- **Documentation**: every behavioural claim backed by code or evidence.
- **Test strength**: vacuous tests, assertion gaps, mocked-away invariants, names that promise more than the test proves.

Where parallel evidence gathering helps, dispatch one read-only review per dimension with `briefs/reviewer.md`, within the cap: judgement tier for subtle semantics, mechanical tier for mechanically checkable audits. Synthesise the findings yourself.

## 2. Exercise the candidate

Use the strongest evidence the specification warrants: the build (once per candidate, before fan-out); unit and integration suites per **Verification budget**, alongside E2E plans but never alongside timing plans; E2E per **E2E verification**; migrations against realistic prior state; fault, retry and restart tests; linters and static analysis; benchmarks; deployment or container builds; targeted runtime experiments. A passing suite is evidence, not proof.

## 3. Test executors

Every suite run (baseline, fix-round targeted suites, final full pass, fault/retry/restart suites) goes to a mechanical-tier test executor with `briefs/test-executor.md`. Build first, then hand over the built worktree and exact commands that don't rebuild (e.g. `dotnet test --no-build`). The executor reports totals, each failure with its message and `file:line`, new versus pre-existing, and environmental signatures separately. It doesn't diagnose.

Before accepting a result, check that it is consistent: the totals match the log tail; every failure in the tail is listed; the candidate SHA and worktree cleanliness are confirmed; every failure marked pre-existing is on the baseline list. Open the full log only if the handover is insufficient. An environmental signature (OOM kill, port in use, timeout, missing SDK) is an environment issue to diagnose read-only, re-running Stage C for OOM or disk; it is not a defect.

**Confirm each new failure before ledgering it.** Dispatch a fresh test executor to run only that test, filtered, twice on the candidate and once on the base worktree:

- fails on the base: pre-existing; add it to the list;
- passes on the base and fails twice on the candidate: a defect; ledger it;
- anything else: flaky; add it to the pre-existing list marked `flaky`, record a residual risk, and don't ledger it.

Implementors still run their own filtered tests while they work.

## 4. Verification budget

- **Fix rounds**: the targeted suites covering the changed code and its direct dependants, plus the E2E plans touching changed behaviour.
- **Final candidate**: one full-suite run, on the candidate you intend to present. A fix round after it requires a new full run.
- Re-run Stage C before each build, suite run or fan-out. Never start a run that can't finish.

## 5. Defect ledger

Keep the defect ledger in `defects.md`:

| ID | Spec criterion | Severity | Evidence | Root cause | Required change | Fix rounds | Status |
|---|---|---|---|---|---|---|---|

Status is `open`, `closed` or `escalated`. Classify each finding:

- **implementation**: the spec is clear; the code is wrong;
- **missing**: required behaviour that no stream delivered;
- **verification**: inadequate evidence, including a wrong or weak E2E plan and confirmation evidence that doesn't prove the outcome;
- **documentation**: prose contradicts demonstrated behaviour;
- **specification**: the spec is incomplete or contradictory, or needs a conductor decision.

A defect that predates the change is in scope only if it violates a locked acceptance criterion. Otherwise record it as a residual risk and tell the conductor. Never widen the change silently.

## 6. Loop

- **Implementation, missing, verification and documentation defects**: never fix them yourself. Plan a DAG of only the work that closes them, dispatch it, and integrate again.
- **Recurrence cap**: a defect still open after two fix rounds gets no third. Reclassify it as a likely specification or contract defect, and escalate it to the conductor with both rounds' evidence: what each fix changed, and why the defect survived. Other defects keep looping.
- **Specification defects**: pause the affected work. Return to Phase 1 with the fewest necessary questions. Issue a revised LOCKED SPECIFICATION naming the invalidated decisions and work, then replan.

---

# E2E verification

E2E verification proves that the candidate meets the specification when a real user or client drives a real surface. It complements the unit and integration suites; it does not replace them.

You design E2E verification and judge its evidence; you never execute it. Browser sessions, screenshots and long transcripts belong in disposable executors, which return only confirmation evidence: the mechanical tier for fixed plans (`briefs/e2e-executor.md`), the judgement tier for exploratory charters (`briefs/e2e-explorer.md`). Read `reference/e2e-design.md` when drafting scenarios (Phase 2) and when writing plans, dispatching and verifying evidence (Phase 4).

Evidence dirs are never committed. Delete them only after the conductor has read the completion report.

---

# Completion Gate

The change is complete only when you can demonstrate all of:

1. Every acceptance criterion maps to concrete evidence.
2. No implementation or integration defect is unresolved.
3. Required build, test, lint and integration checks pass, including one full-suite pass on the final candidate SHA, run by a test executor and reviewed by you.
4. Every fixed E2E plan passes on the final candidate SHA, run by mechanical-tier executors, with confirmation evidence you have reviewed.
5. Tests that guard invariants assert those invariants.
6. Correctness-critical third-party behaviour is verified.
7. Material lifecycle and failure semantics are exercised.
8. Migration and upgrade behaviour meets the specification.
9. No resource grows without an intentional retention policy.
10. Documentation describes observed behaviour.
11. The diff contains no worktree, scratch file, stray generated output or orchestration residue, and every swarm worktree (the base included) and `swarm/*` branch is removed.
12. The diff has no unexplained scope expansion.
13. The **specification**, not merely the plan, is met.

## Delivery

- Repository rules the change itself must satisfy (version bump, docs, tests) are acceptance criteria, delivered by implementors.
- Deliver onto the branch the conductor or session designates. Otherwise use the repository's convention (e.g. `feature/<name>`), confirmed at SPEC LOCK. Moving the accepted composition there by fast-forward or conflict-free merge is plumbing. Then remove the swarm worktrees and `swarm/*` branches.
- Open a pull request only if the conductor asked for one, following the repository's template and conventions.
- You choose the commit trailer and put it in every implementor brief. Precedence: the conductor's instructions, then the repository's rules, then the session's attribution instructions.
- Report using `reference/completion-report.md`, then set `Phase: completion · Status: complete` in `run.md`.

---

# Invocation

- `resume [run]`: follow `reference/recovery.md`.
- A change request: run the phases in sequence, starting with Phase 0.
