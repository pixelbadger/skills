# Conductor

Conductor turns the invoking Claude Code session into an **orchestrator** for large, cross-cutting or risky repository changes. The orchestrator never edits the code itself. It locks a specification with you, splits the work into parallel streams, dispatches them to cheaper worker models in isolated git worktrees, and then reviews and tests the combined result until the specification is satisfied.

## Install

```text
/plugin marketplace add pixelbadger/skills
/plugin install conductor@pixelbadger
```

## Use

```text
/conductor:conductor <change request>
```

The skill only runs when invoked explicitly. Claude will not start it on its own.

## What happens

1. **Preflight.** Checks the host, toolchain and resources, and establishes a green test baseline.
2. **Specification.** Researches the repository, then asks you one decision at a time until nothing is ambiguous, including a budget. You approve the **locked specification** before any code changes.
3. **Planning.** Builds a dependency graph of work streams and routes each to a model tier by risk.
4. **Implementation.** Dispatches workers in parallel, each in its own worktree, up to a concurrency cap sized from free memory and disk.
5. **Integration.** Composes the streams, fans out read-only reviews, test runs and E2E checks, and turns defects into further implementation rounds.
6. **Completion.** Stops at the completion gate and delivers onto the branch you or the repository's rules designate, with a completion report.

## Model tiers

| Tier | Used for | Model |
|---|---|---|
| Orchestrator | Specification, planning, integration | The invoking session |
| Judgement | Semantic changes, subtle reviews, exploratory E2E | `sonnet` |
| Mechanical | Bounded changes, test runs, fixed E2E plans | `haiku` |

Run Conductor from your most capable model. To change the models, edit the Tiers table in `skills/conductor/SKILL.md`.

## Your role

You own intent, priorities, risk appetite, budget and final judgement. Expect to answer questions during the specification phase and to approve the locked specification. After that, the run proceeds without you unless a specification defect, a defect that survives two fix rounds, or the budget needs a decision.
