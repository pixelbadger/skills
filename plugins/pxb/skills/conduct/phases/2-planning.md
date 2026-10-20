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

With the first streams dispatched, set `Phase: implementation` and read `phases/3-implementation.md`.
