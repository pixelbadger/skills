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
- Deliver onto the branch locked in the specification (Phase 1). Moving the accepted composition there by fast-forward or conflict-free merge is plumbing. Then remove the swarm worktrees and `swarm/*` branches.
- Open a pull request only if the conductor asked for one, following the repository's template and conventions.
- Commits carry the trailer set at dispatch (Phase 3).
- Report using `reference/completion-report.md`, then set `Phase: completion · Status: complete` in `run.md`.
