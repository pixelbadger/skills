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

Use the strongest evidence the specification warrants: the build (once per candidate, before fan-out); unit and integration suites per **Verification budget**, alongside E2E plans but never alongside timing plans; E2E per **E2E verification** (SKILL.md); migrations against realistic prior state; fault, retry and restart tests; linters and static analysis; benchmarks; deployment or container builds; targeted runtime experiments. A passing suite is evidence, not proof.

## 3. Verification budget

- **Fix rounds**: the targeted suites covering the changed code and its direct dependants, plus the E2E plans touching changed behaviour.
- **Final candidate**: one full-suite run, on the candidate you intend to present. A fix round after it requires a new full run.
- Re-run Stage C before each build, suite run or fan-out. Never start a run that can't finish.

## 4. Defect ledger

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

## 5. Loop

- **Implementation, missing, verification and documentation defects**: never fix them yourself. Plan a DAG of only the work that closes them (Phase 2), implement it (Phase 3), and integrate again.
- **Recurrence cap**: a defect still open after two fix rounds gets no third. Reclassify it as a likely specification or contract defect, and escalate it to the conductor with both rounds' evidence: what each fix changed, and why the defect survived. Other defects keep looping.
- **Specification defects**: pause the affected work. Return to Phase 1 (`phases/1-specification.md`) with the fewest necessary questions. Issue a revised LOCKED SPECIFICATION naming the invalidated decisions and work, then replan.

When the candidate may satisfy the specification, read `phases/5-completion.md`.
