# Stream ledger

Provisional. This is a draft of the Phase 2 DAG, written early so the conductor can judge the decomposition alongside the spec. It is re-derived after SPEC LOCK; no stream exists yet.

| Stream | Tier | Depends on | State | Commit | Concerns |
|---|---|---|---|---|---|
| S0 rename | mechanical | — | — | — | `git mv` pxb → conduct and skills/conduct → skills/run; update internal paths and commands; legacy run-dir fallback in recovery.md. Runs first: everything else edits the moved tree |
| S1 protocol | judgement | — | — | — | Every seam's contract lives here; worth over-specifying |
| S2 conduct-remote-mode | judgement | S0, S1 | — | — | Must leave local mode unchanged (AC 6); edits existing skill files |
| S3 brief | judgement | S0, S1 | — | — | Reuses conduct Phase 1 by reference; owns tracker-ops.md, the az CLI default and the fixture tracker skill |
| S4 remote-skill | mechanical | S0, S1, S3 | — | — | Thin; pullback delegates to S3 |
| S5 azdo-client | judgement | S1 | — | — | REST side of the protocol plus the stub; the stub must match real 412/test-op semantics (§14 probe) |
| S6 harness-runner | judgement | S1 | — | — | Codes against the AzdoPort interface from S1, so it runs parallel to S5 |
| S7 terraform | judgement | — | — | — | MI entitlement in AzDO is the subtle part |
| S8 cloud-init | mechanical | — | — | — | Contracts fixed in spec: `conduct-remote` bin, LUN 0, profile schema path. Judgement-tier review |
| S9 docs-version | mechanical | S0–S8 | — | — | READMEs, migration note, marketplace.json, plugin.json `conduct` 2.0.0 |

## Contracts per stream

- **S1** `remote/protocol/`
  - JSON Schemas: `payload`, `profile`, `blocked`, `deliveries`.
  - TS types plus constants: tags, comment markers, attachment names.
  - `AzdoPort` interface.
  - Schemas for `conduct.json` / `config.json` (`tracker.skill`) and the profile's `extraPlugins` and `tracker` fields.
  - The tracker-ops return shapes, as fixtures the S3 default and the fixture tracker skill are both checked against.
  - Golden fixtures (payload tarball, `blocked.md`, `deliveries.md`, `run.md` with the `Mode:` line).
  - A constants-match test, used by AC 16.
- **S2** `reference/remote-mode.md`, plus pointer rows and lines in `SKILL.md` and the phase files at each conductor-question site. Owns the drain, partial delivery and push sequence and the `amend.md` resume. Emits the S1 fixture formats exactly.
- **S3** `skills/brief/`
  - Normal mode: read ticket → conduct Phase 1 (minus baseline and Stage A/B) → gate with the headless-surface item → payload → validate → lock (ordered, failure-safe).
  - Resume-amend mode.
  - `reference/tracker-ops.md` (the contract), `reference/tracker-azdo-default.md` (neutral az CLI implementation), and a fixture tracker skill under test fixtures that records calls (AC 18).
- **S4** `skills/remote/`: `status`, `cancel`, `pullback`.
- **S5** `remote/harness/src/azdo/`
  - Implements `AzdoPort` over REST, with managed-identity tokens (`@azure/identity`) and PAT for tests.
  - `remote/harness/test/azdo-stub/`: an in-process fake covering WIQL subset, work item PATCH with rev test, attachments upload/link/unlink, comments, tags, PR create (draft)/abandon/link, plus write counters for AC 9.
- **S6** `remote/harness/src/`
  - Behaviour: poller → claim → verify → prepare → SDK run → `run.md` watcher → checkpoint → exit; cancel; restart-resume; wall-clock ceiling; git credential helper.
  - Supporting pieces: a stub conduct plugin for tests, and the `conduct-remote` bin.
- **S7** `remote/infra/terraform/`: per spec §6.5. `fmt`, `validate` and `tflint` clean.
- **S8** `remote/infra/cloud-init/`: `user-data.yaml.tftpl`, the systemd unit, the profile template, and a Playwright smoke script. Passes `cloud-init schema`.
- **S0**: moves only. No behaviour change beyond command names, the run-dir root and the legacy fallback.
- **S9**: `README.md`, `plugins/conduct/README.md`, `.claude-plugin/marketplace.json`, `plugin.json`.

## Waves (cap 5 ⚙)

1. S0, S1, S7, S8
2. S2, S3, S5, S6, then S4 once S3 lands
3. S9
4. Composition, then Phase 4

Seams to spend integration effort on:
- **S3 ↔ S5 protocol parity:** the tracker-skill path and REST implementing the same ticket protocol. A private tracker skill is a third implementation the run can't see, so tracker-ops.md must be precise enough to implement blind.
- **S2 ↔ S6 signalling:** the `run.md` / `blocked.md` / `deliveries.md` contract.
- **S6 ↔ S8 runtime:** paths, env, profile and service user.
