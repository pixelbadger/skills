# Recovery

A run whose session ended (a crash, a closed terminal, exhausted context) continues in a new session with `/pxb:conduct resume [run]`. Its run directory holds what the last session recorded (see **Run directory** in SKILL.md).

1. **Find the run.** Run the Stage A run directory check first. If a run directory was named, use it. Otherwise look for `run.md` files in `~/.claude/pxb/runs/*/` with this repository's `Repo:` and `Status: active`. If there is one, use it; if there are several, ask the conductor which; if there are none, say so and stop.
2. **Read it.** Read `run.md`, `spec.md`, `streams.md`, `defects.md` and `manifest.md` in full, and list `dispatches/` and `reports/`.
3. **Join the run.** Append this session's id to `Sessions:` in `run.md`.
4. **Verify before relying on anything.** The files record what was believed, not what is true. Check that each manifest entry not marked removed exists (`git worktree list`, `git branch --list 'swarm/*'`, the paths). Check each stream's branch head against the commit in `streams.md` and in its latest report, and whether its worktree is clean. Where the files and reality disagree, believe reality, correct the files, and add a line to `## Decisions` starting `Recovery:` that describes the difference. A dirty worktree under a stream whose dispatch never reported is unfinished work: remove the worktree and branch, and re-dispatch the stream from a fresh one.
5. **Settle what was in flight.** No subagent survives its session. For each dispatch in flight (its number in neither `Processed:` nor `Abandoned:`):
   - if its report file exists, process the report as if the worker had just returned it, evidence review included;
   - if not, add its number to `Abandoned:` and re-dispatch its saved brief as a new dispatch: the next number, a new `REPORT_FILE`, and the current Environment block.

   Abandoned dispatches stay in the spend.
6. **Re-check the environment.** Re-run Stages A and B, and Stage C before the next fan-out. The baseline still holds if the base worktree exists at the base SHA; otherwise rebuild it and re-run the baseline.
7. **Report and continue.** Tell the conductor in a few lines what was recovered: phase, spec version and lock state, stream ledger, open defects, spend, what is being re-dispatched, and any differences step 4 found. Then continue from `Next:`. In the specification phase, carry on grilling from `## Decisions` without asking those questions again.
