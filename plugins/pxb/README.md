# pxb

pixelbadger's Claude Code skills, packaged as one plugin.

## Install

```text
/plugin marketplace add pixelbadger/skills
/plugin install pxb@pixelbadger
```

## Skills

| Skill | Command |
|---|---|
| [Conduct](#conduct) | `/pxb:conduct <change request>` |

## Conduct

> **conduct** */kənˈdʌkt/* (verb): to direct the performance of an orchestra; to organise and carry out.

Conduct puts you in charge of a swarm of agents for large, cross-cutting or risky repository changes. You are the **conductor**; the invoking Claude Code session becomes the **orchestrator**, and never edits the code itself. It locks a specification with you, splits the work into parallel streams, dispatches them to cheaper worker models in isolated git worktrees, and then reviews and tests the combined result until the specification is satisfied.

### Use

```text
/pxb:conduct <change request>
/pxb:conduct resume [run]
```

The skill only runs when invoked explicitly. Claude will not start it on its own.

### What happens

1. **Preflight.** Checks the host, toolchain and resources, and establishes a green test baseline.
2. **Specification.** Researches the repository, then asks you one decision at a time until nothing is ambiguous, including a budget. You approve the **locked specification** before any code changes.
3. **Planning.** Builds a dependency graph of work streams and routes each to a model tier by risk.
4. **Implementation.** Dispatches workers in parallel, each in its own worktree, up to a concurrency cap sized from free memory and disk.
5. **Integration.** Composes the streams, fans out read-only reviews, test runs and E2E checks, and turns defects into further implementation rounds.
6. **Completion.** Stops at the completion gate and delivers onto the branch you or the repository's rules designate, with a completion report.

### Persistence and resume

Each run keeps its state as plain Markdown files in its own directory under `~/.claude/pxb/runs/`. These are a run memory (`run.md`: phase, decisions, Environment block, spend, next step), the specification, the stream and defect ledgers, a manifest of the worktrees and branches it created, every brief it dispatched, and every worker's report. You can read them mid-run, or edit them to steer.

If the session ends mid-run, `/pxb:conduct resume` in a new session finds the repository's active run, checks the recorded state against git and the filesystem, re-dispatches whatever was in flight, and carries on. Name a run directory to pick a specific run. Run directories are kept after a run finishes, for audit, until you remove them.

### Model tiers

| Tier | Used for | Model |
|---|---|---|
| Orchestrator | Specification, planning, integration | The invoking session |
| Judgement | Semantic changes, subtle reviews, exploratory E2E | `sonnet` |
| Mechanical | Bounded changes, test runs, fixed E2E plans | `haiku` |

Run Conduct from your most capable model. To change the models, edit the Tiers table in `skills/conduct/SKILL.md`.

### Your role as conductor

You own intent, priorities, risk appetite, budget and final judgement. Expect to answer questions during the specification phase and to approve the locked specification. After that, the run proceeds without you unless a specification defect, a defect that survives two fix rounds, or the budget needs a decision.
