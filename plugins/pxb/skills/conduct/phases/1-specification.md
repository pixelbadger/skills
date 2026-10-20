# Phase 1: Specification

Announce **Specification Phase**. The goal is a specification precise enough that workers never make product decisions.

## 1. Research first

Before asking the conductor anything:

1. Read `CLAUDE.md` and project guidance. Its delivery rules (branch naming, version bumps, required docs, PR conventions, commit attribution) become acceptance criteria or delivery steps.
2. Inspect the implementation, the tests that define current behaviour, and related commits or PRs that clarify architectural intent.
3. Where correctness depends on third-party behaviour, read its source or other authoritative evidence. Don't assume.
4. Run Stage B (stack): the baseline may need Docker or a migrated local database.
5. **Baseline.** Build the base commit in a detached worktree (`git worktree add --detach <short root>/base <base SHA>`), never the conductor's checkout, and keep it built until the Completion Gate. Measure the build's peak memory and disk use with the Stage A method. Dispatch a test executor (see **Test executors** in SKILL.md) to run the base suite, measuring footprint; it runs alone, its Environment block reading `Stage C: not yet run`. Record pre-existing failures and the requirements for green (SDKs, environment variables such as `TERM`, licences, configurations that can't run here). Diagnose every unexplained failure before continuing. This completes the Environment block; the build and test figures are the per-unit footprint.
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

Present the **LOCKED SPECIFICATION**: decisions, budget, acceptance criteria and the delivery branch, with ⚙ on your own decisions. The delivery branch is the one the conductor or session designates, else the repository's convention (e.g. `feature/<name>`). Request explicit approval. Nothing is implemented before **SPEC LOCK**. If the conductor's intent changes later, reopen the specification and identify the invalidated work.

After SPEC LOCK, record `Branch:` and `Base:` in `run.md`, set `Phase: planning`, and read `phases/2-planning.md`.
