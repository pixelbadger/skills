# Run skills-20261022-7c3a
Repo: <absolute path to your pixelbadger/skills checkout — set before resume> · Branch: feature/conduct-remote (proposed) · Base: <unlocked>
Phase: specification · Status: active
Sessions: claude.ai/code session_01C3HfcyXhzXXC2HKcBBrXd4 (off-host draft)
Request: Integrate conduct with a remote agent. Front-load everything up to SPEC LOCK on the dev's machine via a new skill; dispatch the locked payload through the AzDO work item (attachments plus a conduct:speclock tag) to a single Azure VM running ~5 concurrent streams; drive it all from the dev's Claude Code session. Deliver as new skills, Terraform and cloud-init for the VM, and a harness built on the Claude Agent SDK (TypeScript, Node, pnpm).
Next: Run Stage A/B on this host, then settle spec.md §14 probes, then ask §13 gate questions in order, starting with Q1.
Processed: none
Abandoned: none
Spend: pre-lock only (repo read, Agent SDK docs read; no dispatches)

## Environment
ENVIRONMENT
Base:                  <unlocked>
Env vars / config:     n/a
Known constraints:     Draft produced off-host; Stages A and B not yet run on the run host
Measurement:           not yet run
Pre-existing failures: pending baseline
Footprint (one unit):  disk not yet measured, peak memory not yet measured
Run directory:         ~/.claude/pxb/runs/skills-20261022-7c3a   (this run uses the pre-rename skill)
Stage A: not yet run
Stage B: not yet run
Stage C: not yet run

## Decisions
- Remote scope? → Single VM; one conduct run per box at a time, fanning out to ~5 concurrent units. Farm later.
- Remote environment reach? → Local-only. No cloud envs; must build, test and render/capture with headless Chromium via Playwright.
- Preflight on the remote? → Out. Hard-coded machine metrics (profile) replace measurement-based sizing.
- Persistence layer? → The AzDO work item. Attachments plus a conduct:speclock tag mark the handover; in-flight state must not write to AzDO on every change.
- Trigger? → Not a pipeline; something lighter. (⚙ polling via WIQL plus a /rev-guarded claim; Service Hook → Storage Queue as the upgrade path.)
- Pre-lock work? → A new skill on the dev's machine does research and Q&A up to SPEC LOCK, driven from their Claude Code session.
- On a decision block? → Exit. Ship completed work first so it's off the persisted work list, persist state to the ticket, notify the dev with a "blocked on x" message in the agent's own voice.
- PR state? → All PRs are drafts. Publishing is a human action.
- Rework after delivery? → If the conductor says so: abandon those PRs and pull the branches back into active worktrees.
- Harness stack? → Claude Agent SDK, TypeScript, Node, pnpm.
- Naming? → Plugin prefix is `conduct`: `/conduct:run` (the orchestrator), `/conduct:brief`, `/conduct:remote`.
- pxb plugin and existing users? → Clean break. Conduct moves to its own plugin, pxb is retired, runs move to ~/.claude/conduct/runs/, and resume still finds legacy ~/.claude/pxb/runs/ runs.
- Work-specific AzDO interactions? → A private work plugin implements a tracker-ops seam defined by conduct. The public repo stays generic, with a neutral az CLI default.
- Resume answer path? → (⚙, conductor called it reasonable) Answers return through conduct:brief resume-amend and a re-lock with a new hash and base SHA, not a raw comment the remote reads.

## Lessons
- Conduct's "integrate only a coherent candidate" rule conflicts with "ship completed streams first" — resolved provisionally as closed-sub-DAG partial delivery (spec §13 Q2). — evidence: spec drafting
