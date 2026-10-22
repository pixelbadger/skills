# Conduct Remote — handover

**Status:** draft specification, not locked, nothing implemented. The work is paused at conduct Phase 1, before SPEC LOCK.

The full spec is [`run/skills-20261022-7c3a/spec.md`](run/skills-20261022-7c3a/spec.md). This page is the short version plus the reasoning behind it.

## What it is

Conduct split at SPEC LOCK:
- **Before the lock**, on the developer's machine: research, Q&A and the Zero-Ambiguity Gate.
- **After the lock**, unattended on one Azure VM: baseline, planning, a fan-out of about 5 concurrent units, integration, and delivery as draft PRs.

The AzDO work item is the hand-off point and the coarse persistence layer. Everything is driven from the developer's Claude Code session.

```text
 dev machine                     AzDO work item                    agent VM
 ───────────                     ──────────────                    ────────
 /conduct:brief <ticket>
   research + Q&A + gate
   LOCKED SPECIFICATION ──────▶  payload-v<n>.tar.gz
                                 lock comment (sha256)
                                 tag conduct:speclock ◀──── poll (WIQL, 60s)
                                 tag conduct:running  ◀──── claim (JSON Patch + /rev test)
                                                             /conduct:run remote <runDir>
                                                               baseline → plan → fan-out
                                                               → integrate → deliver
                                 checkpoint-<seq>.tar.gz ◀── on each Phase/Status change only
                                 draft PR(s) linked      ◀── deliveries
                                 tag conduct:done | conduct:blocked
 /conduct:brief <ticket>  ◀───── "blocked on X" comment, @mention
   (resume-amend) → re-lock v<n+1> ─▶ … loop
 /conduct:remote status | cancel | pullback
```

## Decisions and why

| Decision | Why |
|---|---|
| Single VM, one run at a time, fanning out to about 5 units | Simplest thing that works. A farm of VMs comes later. |
| Remote work is local-only: build, test, headless Chromium via Playwright | No cloud credentials on the box. Every E2E surface must be headless-runnable, which becomes an extra gate item in brief. |
| Polling plus a `/rev`-guarded claim, not a pipeline | No inbound endpoint, no extra infrastructure, and AzDO's optimistic concurrency gives an atomic claim. If latency ever matters, the upgrade path is a Service Hook to an Azure Storage Queue. |
| Three persistence tiers | Each tier does one job: **git remote** holds work product (WIP branches pushed); the **local run dir** holds scratch (conduct's existing Markdown); **AzDO** holds control state, written only at Phase/Status transitions (3 writes each, none per worker report). |
| Checkpoints are tarballs of the run dir | Restoring is untar plus conduct's existing `resume`. No new persistence format. |
| Conduct never talks to AzDO | In remote mode it writes only run-dir signals: a `Mode:` line, `Status: blocked`, `blocked.md` and `deliveries.md`. The harness owns all ticket I/O, so the public skill stays tracker-agnostic. |
| A hard-coded machine profile replaces preflight | It supplies the concurrency cap, footprint, per-slot ports and paths. The Stage C disk probe still runs as a guard. |
| Baseline runs on the VM | Pre-existing failures depend on the host. A baseline failure is a decision block raised before any work. |
| Only decision blocks exit | Three things can stop a stream, and only one needs a human: **decision** (spec gap, a defect surviving two fix rounds, budget), which exits the run; **dependency**, which the orchestrator handles internally; **environment**, which self-heals and escalates once its retry budget runs out. |
| The decision-block exit is drain, partial-deliver, push, signal | Completed work ships first so it's off the persisted work list. Then state goes to the ticket and the dev gets an agent-voiced "blocked on X". |
| Partial delivery is the closed sub-DAG | Conduct integrates only coherent candidates. Accepted streams with no dependency path to the blocked one get their own Phase 4 and ship as draft PR `p<k>`. Everything else is pushed as WIP. |
| An interface-level block halts the run | If the block invalidates a locked interface, the remote never re-plans on its own. The ticket goes back to brief, which keeps speclock meaningful. |
| The answer goes back through `conduct:brief` resume-amend and a re-lock | One door in. The hash check stays honest, and the base SHA moves to absorb merged PRs. |
| All PRs are drafts | Publishing is a human action. |
| Pullback | On the conductor's say-so, `Reopen:` streams have their draft PRs abandoned and their branches restored into worktrees on the VM. |
| Tracker seam | `tracker-ops.md` defines protocol operations and conventions (spec/DoD, branch naming, PR conventions). A **private work plugin** implements it; the public repo ships only a neutral `az` default. Conduct owns the protocol constants; the tracker skill owns the conventions. On the VM it's loaded via `extraPlugins` and cloned with the managed identity. |
| Rename, as a clean break | `pxb` → `conduct`, giving `/conduct:run`, `/conduct:brief` and `/conduct:remote`. Runs move to `~/.claude/conduct/runs/`, with a legacy `~/.claude/pxb/runs/` fallback on resume. The plugin goes to 2.0.0. |
| Harness stack | Claude Agent SDK, TypeScript, Node LTS, pnpm. The plugin is loaded by path and `/conduct:run …` is dispatched as the prompt. Auth is an API key from Key Vault, never a claude.ai login. |
| VM | 16 vCPU / 64 GB class (default `Standard_D16s_v5`); Premium SSD data disk at `/work` for worktrees and shared NuGet/npm/pnpm caches. No inbound network. Managed identity for AzDO and git. |

## Open before lock

Gate questions, asked one at a time on resume (spec §13):

1. **Repo home.** Harness and infra under `remote/` in this public GPL repo? This is recommended now that org specifics live in the private plugin.
2. **Partial delivery as the closed sub-DAG.** Confirm, rather than shipping individual unintegrated streams.
3. **Cloud evidence.** Should the Terraform plan and real-VM smoke run in-run, or as a scripted post-delivery acceptance (recommended)?
4. **Budget.** Proposed: 3 rounds, 10 streams, 50 subagents, 6h.
5. **AzDO only in v1**, behind the `AzdoPort` seam (recommended).
6. **Permissions.** `bypassPermissions` plus a path-guard hook on the dedicated VM (recommended).

Probes to settle by experiment, not carry as risk (spec §14):
- AzDO returns 412 on a stale-rev test op.
- A managed identity can be entitled in AzDO via Terraform, and git accepts its bearer token.
- Unlinking an attachment behaves as described in the spec.
- `az` covers the brief and remote operations.
- Cross-plugin Skill invocation works.
- Subagent model overrides are honoured in SDK sessions.

## Plan (provisional)

There are ten streams; see [`streams.md`](run/skills-20261022-7c3a/streams.md).
- **S0 rename** goes first, alone, because everything else edits the moved tree.
- **S1 protocol** (schemas, constants, `AzdoPort`, fixtures) goes first because every seam's contract lives there.
- S2–S8 then fan out.
- Integration effort goes on three seams:
  - **protocol parity** across the tracker skill, the `az` default and the REST harness;
  - **signalling** between conduct remote mode and the harness;
  - **runtime contract** between the harness and cloud-init.

A private tracker skill is a third protocol implementation the run can't see, so `tracker-ops.md` must be implementable blind.

## Picking it up

This run uses the current, pre-rename skill, because the rename is part of the run.

1. Copy `run/skills-20261022-7c3a/` to `~/.claude/pxb/runs/`.
2. Set the `Repo:` line in its `run.md` to your checkout of this repo.
3. Run `/pxb:conduct resume skills-20261022-7c3a`. It runs Stage A/B, then the §14 probes, then the gate questions. Decisions already recorded won't be asked again.
4. Approve the LOCKED SPECIFICATION. The run continues from there.

## Files

| File | Holds |
|---|---|
| `run/skills-20261022-7c3a/spec.md` | Specification, draft v1: contracts, behaviour, acceptance criteria, E2E scope, gate questions, probes |
| `run/skills-20261022-7c3a/run.md` | Run memory: decisions so far, next step |
| `run/skills-20261022-7c3a/streams.md` | Provisional DAG, stream contracts, waves, seams |
| `run/skills-20261022-7c3a/manifest.md`, `defects.md` | Empty ledgers |
