Status: draft (v1)

# Conduct Remote — specification

Produced off-host from a conversation with the conductor. It has not been through the Phase 1 baseline or Stages A/B on the run host. ⚙ marks orchestrator decisions for the conductor to override at approval. Open gate questions are in §13 and must be settled before SPEC LOCK.

## 1. Goal

Split a conduct run at SPEC LOCK:

- Everything up to the lock (research, grilling, the Zero-Ambiguity Gate) happens on the developer's machine.
- Everything after it (baseline, planning, implementation, integration, delivery) happens unattended on a single Azure VM.

The Azure DevOps (AzDO) work item is the hand-off point and the coarse-grained persistence layer. All of it is driven from the developer's Claude Code session.

## 2. Non-goals

- More than one run per VM at a time; a farm of VMs; a scheduler across VMs.
- Trackers or code hosts other than AzDO Boards and AzDO Repos in v1 (adapter seam only, see §5.6).
- Pipelines as the trigger.
- Remote runs that touch any cloud environment. Remote work is local-only: build, test and headless browser on the VM.
- Publishing or completing PRs. The remote opens drafts only; publishing is a human action.
- Changing local conduct behaviour beyond the rename (§4a).
- Preflight sizing on the remote: footprint and concurrency come from a fixed machine profile.
- The private work plugin itself. This run delivers the tracker seam, a generic default and a conformance fixture; org conventions live in the work plugin (§5.7).

## 3. Current behaviour (from `plugins/pxb/skills/conduct`, v1.1.0)

- Phase 0 preflight: Stage A host checks, peak-memory measurement, run directory.
- Phase 1: research, baseline, one-question-at-a-time grilling, Zero-Ambiguity Gate, SPEC LOCK.
- Phases 2–5: plan, implement, integrate and complete with no conductor, except at three escalation points:
  - a specification defect;
  - a defect that survives two fix rounds;
  - a budget overrun.
- State lives as Markdown in `~/.claude/pxb/runs/<run>/`. `resume` reconstructs from files, verified against git.
- Delivery goes to one branch, with a PR only if asked. Integration is only ever on a coherent candidate containing every accepted stream.

## 4. Components to deliver

| # | Component | Location ⚙ (see Q1) |
|---|---|---|
| C0 | Plugin rename: `pxb` → `conduct`, skill `conduct` → `run` | `plugins/conduct/`, marketplace |
| C1 | Protocol package: schemas, types, constants, fixtures | `remote/protocol/` |
| C2 | Conduct remote mode | `plugins/conduct/skills/run/` (additive) |
| C3 | `conduct:brief` skill: pre-lock research, Q&A, payload, lock, resume-amend | `plugins/conduct/skills/brief/` |
| C4 | `conduct:remote` skill: status, cancel, pullback | `plugins/conduct/skills/remote/` |
| C5 | AzDO client and stub server | `remote/harness/src/azdo/`, `remote/harness/test/azdo-stub/` |
| C6 | Harness runner (`conduct-remote` binary) | `remote/harness/` |
| C7 | Terraform for the agent VM | `remote/infra/terraform/` |
| C8 | cloud-init, systemd units, machine profile | `remote/infra/cloud-init/` |

Harness stack: TypeScript, Node LTS, pnpm (via corepack), `@anthropic-ai/claude-agent-sdk`.

## 4a. Rename (clean break)

- `plugins/pxb/` becomes `plugins/conduct/`, and `skills/conduct/` becomes `skills/run/` (`git mv`, so history follows). The `pxb` plugin is removed from the marketplace, with no alias.
- The commands are `/conduct:run`, `/conduct:brief` and `/conduct:remote`.
- New runs go in `~/.claude/conduct/runs/`. `/conduct:run resume` also searches `~/.claude/pxb/runs/` and resumes an old run in place without moving it.
- The plugin manifest is `conduct` at version 2.0.0 ⚙, which marks the break.
- The README carries a migration note: uninstall `pxb@pixelbadger`, then install `conduct@pixelbadger`.

## 5. Contracts

### 5.1 Ticket protocol (AzDO work item)

**Tags.** Exactly one `conduct:*` state tag is present at any time (invariant).

| Tag | Set by | Meaning |
|---|---|---|
| `conduct:speclock` | brief | Locked payload attached; claimable |
| `conduct:running` | harness | Claimed by the VM |
| `conduct:blocked` | harness | Decision block; awaiting the dev |
| `conduct:cancel` | remote skill | Cancel requested; the harness treats it as a block with reason "cancelled" |
| `conduct:done` | harness | Completed; draft PR(s) open |
| `conduct:failed` | harness | Harness or infra failure, not a decision; needs a human |
| `conduct:rejected` | harness | Payload invalid; reason in comment |

**Attachments.** Attachments are immutable, so each upload is new and the previous one is unlinked (not deleted).

- `conduct-payload-v<n>.tar.gz`, linked at lock.
- `conduct-checkpoint-<seq>.tar.gz`, linked at each checkpoint. At most one checkpoint attachment is linked at a time.

**Comments.** The first line is the machine marker; the rest is human prose.

- Lock: `conduct:lock v<n> sha256:<hex>`. The latest lock comment wins.
- Block: `conduct:blocked <run> seq:<seq>`, then the agent-voice message from `blocked.md`, with an @mention of the lock comment's author.
- Checkpoint: `conduct:checkpoint <run> seq:<seq> phase:<phase>`, then one line of status.
- Done, failed and rejected follow the same `conduct:<state> …` shape.

**Claim.** A JSON Patch that removes `conduct:speclock` and adds `conduct:running` is guarded by `{"op":"test","path":"/rev","value":<rev read>}`. A 412 or test failure means the claim is lost: re-query and do not retry blindly.

**Trust ⚙**
- The harness acts only on lock comments authored by an identity in the profile's `allowedLockers`.
- The agent never receives the ticket's description or comments. It receives only the payload.

### 5.2 Payload (`conduct-payload-v<n>.tar.gz`)

```text
manifest.json   schema remote/protocol/schemas/payload.schema.json
spec.md         Status: locked (v<n>), conduct's spec format, budget and delivery branch included
decisions.md    one line per conductor answer (seed for run.md ## Decisions)
amend.md        resume-amend only: answer to the block, invalidated decisions, Reopen: <streams>
```

`manifest.json` holds:
- `ticket` (org, project, id) and `version`;
- `repo`: AzDO Repos URL, `baseRef`, `baseSha`;
- `deliveryBranch`, `targetBranch`;
- `budget`: rounds, streams, subagents, wallClock;
- `lockedBy`, `lockedAt`;
- `priorRun`: run directory name or null.

The sha256 in the lock comment is over the tarball bytes.

### 5.3 Run-directory signalling (conduct remote mode → harness)

The harness reads only these. Conduct never calls AzDO.

- `run.md` header gains `Mode: remote · Ticket: <org>/<project>#<id> · Profile: <path>`.
- `Status:` gains `blocked`.
- `blocked.md` (written before `Status: blocked`) contains:

  ```text
  Kind: decision | budget | recurrence | baseline | cancelled
  Stream: <id or ->
  Question: <one line>
  Options: <a/b/... with the orchestrator's recommendation>
  Shipped: <delivery ids or none>
  Waiting: <stream ids>
  ---
  <agent-voice message, ≤ 8 lines, answerable in one reply>
  ```

- `deliveries.md`: one row per delivery, with id, branch, head SHA, streams included, PR title, PR body path, and state (`pushed`, `pr-open`, `abandoned`). Conduct pushes the branch; the harness opens or abandons the PR and records its URL.

### 5.4 Machine profile (`/etc/conduct-remote/profile.json`, schema in C1)

- `concurrencyCap` (5);
- `footprint` (disk, peak memory, per unit);
- `slots[]`: per-unit port range, `PORT_BASE` env and data dir;
- paths: `worktreeRoot` `/work/sw`, `runsRoot` `/work/runs`, `cacheRoot` `/work/cache`;
- `playwrightBrowsersPath` `/opt/pw-browsers`;
- `wallClockCeiling` (10h);
- `allowedLockers[]`;
- `azdo` (org, project) and `pollSeconds` (60);
- `extraPlugins[]`: local paths of further plugins loaded into the SDK session, such as the work plugin;
- `tracker.skill`: as in §5.7.

In remote mode, the profile replaces Stage A's peak-memory check and the Stage C memory quotient. The Stage C disk probe still runs ⚙.

### 5.5 Harness ↔ Agent SDK

- `query({ prompt: "/conduct:run remote <runDir>" | "/conduct:run resume <runDir>", options })`;
- `plugins: [{type:"local", path:<checked-out conduct plugin>}]`, `cwd` set to the run's composition root;
- model: Opus tier; the Agent tool is available, and subagents use conduct's Tiers table;
- `permissionMode: "bypassPermissions"` with a `canUseTool` / PreToolUse hook that denies writes outside `/work` and `/tmp/sw` ⚙ (Q6).

Before proceeding, the harness asserts that the init message lists `conduct:run` in `slash_commands`. Auth is `ANTHROPIC_API_KEY` from Key Vault, never claude.ai login.

### 5.6 Adapter seam

`AzdoPort` (a TS interface in C1) covers: query claimable, claim, read/attach/unlink files, comment, set tag, open draft PR, abandon PR, link PR to work item. v1 has one implementation (C5) plus the stub. GitHub is a non-goal (Q5).

### 5.7 Tracker seam (skills side)

The skills need two things from the tracker: protocol operations and org conventions. They delegate both to a **tracker skill**, so org specifics live in a private work plugin and never in this repo.

**Contract.** The contract is defined in `plugins/conduct/skills/brief/reference/tracker-ops.md`. Each operation has a name, arguments and the exact return shape.

| Kind | Operations |
|---|---|
| Protocol | `getWorkItem`, `getComments`, `downloadAttachment` (by name or latest of a prefix), `attach`, `unlinkAttachment`, `comment` (with optional mention), `swapStateTag` (from → to, rev-guarded), `abandonPr` |
| Conventions | `specConventions`: where ACs live, required spec sections, definition-of-done items that become acceptance criteria |
| | `branchName`: from ticket and slug, to delivery branch |
| | `prConventions`: title format, body template, reviewers, work-item linking |

**Resolution.**
- The tracker skill is named in `tracker.skill` (`<plugin>:<skill>`).
- The setting is read from `.claude/conduct.json` in the repo first, then `~/.claude/conduct/config.json` (schema in C1).
- If neither sets it, the built-in default applies: the generic `az` CLI implementation in `reference/tracker-azdo-default.md`, with neutral conventions. The tracker skill is invoked through the Skill tool, one operation per call.

**Ownership.**
- Conduct owns the protocol constants (§5.1): tags, markers, attachment names, the hash rule and the claim guard. A tracker skill implements the operations but never chooses those values.
- The tracker skill owns everything conventional.

**Remote side.** The profile names the same tracker skill and lists its plugin under `extraPlugins`. On the VM, `conduct:run` asks it for `branchName` and `prConventions` when writing `deliveries.md`, so PR title, body and reviewers follow org conventions. The harness's REST client stays generic: it executes protocol operations and copies title, body and reviewers from `deliveries.md` without interpreting them.

## 6. Required behaviour

### 6.1 `conduct:brief <ticket>` (developer machine)

All tracker access in this skill and in `conduct:remote` goes through the tracker seam (§5.7). Neither skill calls `az` directly.

1. Read the work item (`getWorkItem`, `getComments`) and the org's `specConventions`. The conventions' definition-of-done items join the acceptance criteria.
2. Run conduct Phase 1 §1 steps 1–4 and 6 (research; no baseline, no Stage A/B). Then run §2 grilling and §3 model, by reading conduct's `phases/1-specification.md` rather than duplicating it.
3. Zero-Ambiguity Gate, as in conduct, except that the baseline and Stage A/B items transfer to the remote. Add one item: every E2E surface must be runnable headless on the VM (CLI, API, Playwright/Chromium). Chrome MCP is not available remotely.
4. Present the LOCKED SPECIFICATION, with the delivery branch from `branchName`, and get explicit approval.
5. Build the payload, validate it against the schema, `attach` it, post the lock `comment` and `swapStateTag` to `conduct:speclock`, in that order. A failure part-way leaves no `conduct:speclock` tag.

**Resume-amend mode** (`conduct:brief <ticket>` on a `conduct:blocked` ticket):
- Download the latest checkpoint and show the block.
- Take the answer and write `amend.md`: the answer, the decisions it invalidates, and a `Reopen:` list.
- Bump the spec to v<n+1> with a new base SHA. Re-lock with `manifest.priorRun` set.
- If the answer touches a stream in a delivery that is `pr-open`, list that stream in `Reopen:` and say so to the dev. Do not re-lock silently.

### 6.2 `conduct:remote` (developer machine)

- `status <ticket>`: state tag, phase, spend, deliveries with PR links and, if blocked, the question. Read from comments and the latest checkpoint.
- `cancel <ticket>`: sets `conduct:cancel`.
- `pullback <ticket> <streams|delivery>`: a thin wrapper that runs `conduct:brief` resume-amend with those streams in `Reopen:`.

### 6.3 Conduct remote mode (`/conduct:run remote <runDir>`, VM only)

A new `reference/remote-mode.md` lists overrides. It is read only in remote mode, and everything not overridden is unchanged.

- **Phase 0.** Stage A is replaced by the profile, except for the base-commit, toolchain and feed checks, which still run. A `raised` check is a decision block of kind `baseline`.
- **Phase 1.** No grilling. The spec arrives locked. Run §1 step 5 (baseline) only. An unexplained baseline failure is a decision block of kind `baseline`.
- **Phase 2.** Runs unchanged. The DAG is written to `streams.md`; there is no "show the conductor" wait.
- **Every conductor question** (spec defect, recurrence cap, budget) triggers the **decision-block exit**:
  1. **Drain.** In-flight dispatches finish within budget. Nothing new starts.
  2. **Partial delivery** (Q2). Take the closed sub-DAG: accepted streams with no dependency path to or from the blocked stream. Compose it, run Phase 4 on that partial candidate under the normal rules, and push it as delivery `p<k>`.
  3. **Push.** Every other accepted or ready `swarm/*` branch is pushed as WIP.
  4. **Signal.** Write `blocked.md`, then set `Status: blocked`, then end the turn.
- **Phase 5 delivery.** Push the delivery branch and record it in `deliveries.md`, with PR title, body and reviewers from the tracker skill's `prConventions` (the default if none is configured). The PR is opened by the harness, always as a draft.
- **Resume with `amend.md`.**
  1. Streams in `Reopen:` move from `accepted` to `rejected`.
  2. Their deliveries are marked for abandonment, and the harness abandons the PRs.
  3. Their worktrees are recreated from the pushed branches.
  4. The remaining WIP branches are rebased onto the new base. A rebase conflict is a decision block.
- **Local mode is unchanged** apart from the rename (§4a). The only other edits to existing files are the invocation and Skill-files table rows and one pointer line per conductor-question site.

### 6.4 Harness (`conduct-remote`, systemd service)

- **Poll** every `pollSeconds` with WIQL for `conduct:speclock` or `conduct:cancel` in the profile's project. Skip claiming while a local run is `active`.
- **Claim.** Use the §5.1 claim. Download the payload and verify its sha256 against the latest lock comment and its schema. On mismatch, set `conduct:rejected` with a reason and create no workspace.
- **Prepare.** For a fresh run: clone into `/work`, create the run directory under `runsRoot`, and seed `run.md`, `spec.md` and `## Decisions` from the payload. For `priorRun`: restore from the local directory if present, else from the latest checkpoint attachment, then apply `amend.md`.
- **Run.** Start the SDK per §5.5 with `remote` (fresh) or `resume` (restored or crashed), passing the profile path and slot env.
- **Watch `run.md`.** On every `Phase:` or `Status:` change, upload a checkpoint, link it, unlink the previous one, and comment. That means 3 AzDO writes per transition and none per worker report ⚙.
- **Exit.**

  | Run ends with | Harness does |
  |---|---|
  | `blocked` | Open draft PRs for new deliveries, checkpoint, set `conduct:blocked`, comment from `blocked.md` with @mention |
  | `complete` | Open draft PRs, checkpoint, set `conduct:done` |
  | Process failure | One `resume` retry, then checkpoint and `conduct:failed` |
  | Wall-clock ceiling reached | Kill, checkpoint, then treat as `blocked` with `Kind: budget` |

- **Cancel.** On `conduct:cancel` for the active ticket, interrupt the query, checkpoint, set `conduct:blocked` with `Kind: cancelled`.
- **Restart.** On service start, a local run that is `active` with its ticket `conduct:running` is resumed with no AzDO read.
- **Credentials.** Git and AzDO use a managed-identity bearer token, via a credential helper and `http.extraHeader`. There are no PATs on the box.
- **Logs.** Structured JSON to journald, plus the SDK message stream to `runDir/sdk.log`.

### 6.5 Infrastructure

**Terraform:**
- resource group, VNet/subnet, NSG with no inbound rules by default (optional SSH allowlist variable);
- Ubuntu 24.04 LTS VM, `vm_size` default `Standard_D16s_v5` ⚙, with a system-assigned managed identity;
- Premium SSD OS disk plus a data disk at LUN 0 (default 512 GiB) mounted at `/work`;
- Key Vault (RBAC) holding `anthropic-api-key`, with Secrets User granted to the managed identity;
- AzDO entitlement for the managed identity (Basic) and project Contributor via the `azuredevops` provider;
- outputs: VM id, managed-identity principal id.

**cloud-init:**
- mount `/work`;
- Node LTS (pinned major) with corepack pnpm;
- git, az CLI, .NET SDK (version variable), Docker;
- `npx playwright install --with-deps chromium` into `/opt/pw-browsers`;
- `conduct-remote` user;
- the harness and the conduct plugin checked out at a pinned ref;
- each `extra_plugins` entry (repo URL and ref) cloned with the managed-identity token, so a private work plugin in AzDO Repos needs no extra credential, and listed in the profile;
- `profile.json` rendered from Terraform variables;
- systemd service with `Restart=on-failure`.

## 7. Failure and lifecycle semantics

| Event | Behaviour |
|---|---|
| Two pollers race (re-provision overlap) | `/rev` test: exactly one wins |
| Payload edited after lock | Hash mismatch → `conduct:rejected` |
| Harness crash or VM reboot | systemd restart → local resume, no AzDO read |
| VM destroyed | Re-provision, re-tag `speclock` (dev, via `conduct:brief`) → restore from checkpoint plus pushed branches |
| Checkpoint upload fails | Retry ×3 with backoff, then continue the run. The next transition retries; the gap is logged |
| AzDO unreachable at exit | Retry until the ceiling; the local state is authoritative meanwhile |
| Draft PR creation fails | The delivery stays `pushed`, and it is noted in the exit comment |

## 8. Compatibility and migration

- Breaking: `/pxb:conduct` is gone. Users reinstall as `conduct@pixelbadger` (§4a).
- Existing run directories under `~/.claude/pxb/runs/` still resume, in place, through `/conduct:run resume`.
- Local behaviour is otherwise unchanged.

## 9. Operational, resource and security constraints

- Concurrency cap 5, from the profile.
- Each slot gets its own port range and data dir. Shared NuGet, npm and pnpm caches live under `/work/cache`.
- No inbound network. Egress only to Anthropic, AzDO, package feeds and GitHub (for the plugin).
- The API key is read from Key Vault at service start and never written to disk or logs.

## 10. Acceptance criteria

1. `conduct:brief` against the stub produces a schema-valid payload, uploads it, posts the lock comment with the correct sha256 and sets `conduct:speclock`. Injected failures at each step leave no `speclock` tag.
2. `conduct:brief` resume-amend on a blocked ticket produces `amend.md` and spec v<n+1>. If a `pr-open` stream is touched, it lands in `Reopen:` with a message to the dev.
3. `conduct:remote status|cancel|pullback` behave per §6.2 against the stub.
4. Conduct remote mode on a fixture repo, with a scripted spec defect in stream B of A→C, B independent:
   - A and C are delivered as `p1` after Phase 4 on the partial candidate;
   - B is pushed as WIP;
   - `blocked.md` validates against the fixture format;
   - the run ends with `Status: blocked`.
5. On resume with `amend.md` reopening A: A's delivery is marked abandoned, A's worktree is restored from its branch, and the run continues to completion.
6. Local `/conduct:run` on the same fixture produces the same phase sequence and files as `/pxb:conduct` v1.1.0 (no `Mode:` line, no `blocked.md`). A run directory created by v1.1.0 under `~/.claude/pxb/runs/` resumes with `/conduct:run resume`.
7. Two harness instances against one stub ticket: exactly one claims.
8. Tampered payload → `conduct:rejected`, no workspace created.
9. One checkpoint (3 writes) per `Phase:`/`Status:` change and zero per report, counted on the stub.
10. Delete the local run directory mid-run, re-lock, and the run resumes from the checkpoint to completion.
11. `kill -9` the harness during implementation; it resumes locally with zero AzDO reads before the next transition.
12. Draft PRs only, linked to the work item; no publish or complete call exists in C5.
13. The wall-clock ceiling produces `Kind: budget`.
14. `terraform fmt -check`, `validate` and `tflint` pass, and `terraform plan` against a sandbox subscription is clean (Q3).
15. cloud-init passes `cloud-init schema`. On a fresh VM:
    - the service is active;
    - a Playwright smoke test renders a page to PNG headless;
    - `profile.json` validates;
    - `/work` is mounted from LUN 0.
16. Protocol constants (tags, markers, attachment names) used by C3, C4 and `tracker-azdo-default.md` match C1, checked by a test.
17. READMEs document run, brief, remote, remote mode, the tracker seam and the migration. The marketplace lists `conduct` and not `pxb`; plugin.json is `conduct` 2.0.0. No `pxb:` reference remains outside the migration note and the legacy-run fallback.
18. With `tracker.skill` set to the in-repo fixture tracker skill, `conduct:brief` and `conduct:remote` route every tracker operation through it. The fixture records every call; zero `az` invocations come from the skills themselves.
19. With no `tracker.skill` configured, the built-in default completes AC 1 against the stub.
20. On the VM, a configured tracker skill's `prConventions` (fixture) determines PR title, body and reviewers in `deliveries.md`, and the harness passes them through unchanged.

## 11. E2E scope

| Criteria | Surface | Tooling and environment |
|---|---|---|
| 1–3, 7–13, 16, 18–20 | CLI | Harness and skills against the in-repo AzDO stub (C5) and a local bare git remote. For harness tests, conduct is replaced by a stub plugin that scripts `run.md` transitions ⚙ |
| 4–6 | CLI | Real conduct, remote mode, on a tiny fixture repo, with real models within budget |
| 14–15 | CLI | Sandbox Azure subscription and AzDO test project (Q3) |

## 12. Budget (proposed, Q4)

- 3 implementation rounds
- 10 streams
- 50 subagents
- 6h wall clock

Delivery branch: `feature/conduct-remote` ⚙.

## 13. Gate questions (one at a time, in this order)

1. **Repo home.** `pixelbadger/skills` with a `remote/` tree (recommended: payload and signalling contracts version with the skills that produce them), or a separate repo? Note that `pixelbadger/skills` is public GPL-3.0, so the harness and infra would be too. Nothing Preservica-specific would be committed: AzDO org and project are variables, and org conventions live in the private work plugin (§5.7).
2. **Partial delivery.** Conduct integrates only a coherent candidate. "Ship completed streams first" is met by delivering the closed sub-DAG after its own Phase 4 (recommended), not by shipping individual unintegrated streams. Confirm.
3. **Cloud evidence.** Should AC 14–15 run in-run against a sandbox subscription and AzDO test project (needs credentials on the run host), or as a scripted conductor acceptance after delivery (recommended; recorded as a residual risk until done)?
4. **Budget.** Is §12 acceptable?
5. **AzDO only in v1**, with the `AzdoPort` seam (recommended)?
6. **Permission posture.** `bypassPermissions` plus a path-guard hook on a dedicated VM (recommended), or `acceptEdits` with an allow-list?

## 14. Probes before lock (checkable; settle them, don't carry them as risk)

- AzDO work item PATCH with a `/rev` test op returns 412 on a stale rev (stub behaviour must match).
- A managed identity can be entitled in AzDO via the `azuredevops` Terraform provider resource, and git-over-HTTPS accepts its bearer token.
- Attachment unlink (removing the relation) leaves the file retrievable and does not error on re-link.
- `az boards` / `az devops invoke` cover every brief and remote operation, or name the REST calls needed.
- A skill can invoke another installed plugin's skill through the Skill tool, both locally and in an SDK session with the plugin loaded by path, and receive its output in-turn.
- Agent SDK: in a non-interactive session with the Agent tool, subagent `model` overrides `sonnet`/`haiku` are honoured, and `slash_commands` lists `conduct:run` when the plugin is loaded by path.
