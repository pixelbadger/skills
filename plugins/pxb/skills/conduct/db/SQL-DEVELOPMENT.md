# Run database: SQL development

How to change the run database without losing its shape. The scripts' interface is in [API.md](API.md).

## Purpose decides content

The database exists for **recovery**: a fresh orchestrator, in a new session, continuing a run. Persist what that orchestrator would otherwise have to reconstruct or guess: decisions, the spec, the ledgers, what is running, what exists on disk. Do not persist what it can re-derive cheaply and reliably from git or the filesystem, and do not persist transcripts.

Before adding anything, name the recovery step that reads it.

## Loose by default

Every entity is the same thing at heart: a row with a session reference and a `context` JSON object. Most of what an agent records is context, and for most recovery a session reference plus context is enough.

A **typed column** earns its place only when something queries it: a view filters, joins, orders or groups on it, a constraint checks it, or a script needs it. Lifecycle states (`state`, `status`), foreign keys, and the identifiers recovery verifies against reality (`commit_sha`, `path`, `branch`) qualify. Prose, evidence, lists that nothing filters on, and anything "might be useful" do not.

## Promote, don't predict

New data starts in context. The scripts route unknown keys there, so recording something new needs no schema change at all.

When a view or script starts needing a context key, promote it to a column in a migration: add the column, backfill it from `json_extract(context, '$.key')`, remove the key from context, and update the views. Don't add columns ahead of a query that needs them.

## Normalise only for a use case

A separate entity, or a relationship between entities, needs a query that would be awkward or impossible without it. The existing ones each have one:

- `report` is separate from `dispatch` because recovery needs "dispatches whose worker finished but whose report was never processed" (`v_in_flight.has_report`), and because the two have different owners.
- `artifact` rows exist so cleanup and recovery can list exactly what this run may delete (`v_live_artifacts`).
- `session.resumed_from` exists so a run survives any number of resumptions as one lineage.

Lists nothing queries (a stream's dependencies, a defect's evidence) stay as JSON in context.

## Views are the query API

Standard questions are answered by views, not by SQL written at the call site. Agents call `get.py <view>`; they never write SQL. If a question recurs, it becomes a view.

- Name views `v_<noun>`.
- A view about a run exposes `session_id` as the session asking, and covers its whole lineage by joining through `v_lineage`. A caller then filters on `session_id` alone, whichever session of the run it is in.
- `v_resume` is the union of the recovery sections, one row per item with a JSON `body`. A new recovery need is usually a new section there.
- Keep views on the base tables or on other views. Don't embed formatting; `resume.py` renders.

## Integrity lives in the schema

Put an invariant where it can't be bypassed:

- foreign keys for references, with `ON DELETE CASCADE` from a session to everything under it;
- `CHECK` for lifecycle vocabularies and JSON validity;
- triggers for cross-row rules (`report_matches_dispatch`);
- the `entity_owner` table for who may write what.

SQLite can't alter a `CHECK` in place: widening a vocabulary means rebuilding the table in a migration. That cost is deliberate, so constrain only vocabularies that the views and the skill depend on. Free-text classifiers (`note.kind`, `defect.severity`) are left open.

## Generic scripts, entity-agnostic

There is one script per operation (`add`, `update`, `remove`, `get`, `resume`), never one per entity. Each takes the entity name first and learns its columns from the schema. Adding an entity is a schema change only: create the table, add its `entity_owner` row, add views. If a change seems to need entity-specific code in a script, look for a constraint, trigger or view that does the job instead.

## Ownership

Every entity has owning roles in `entity_owner`. The write scripts refuse other roles, and a `role` column, where an entity has one, always records the writer. The orchestrator owns orchestration state; each worker owns only its own reports. Give a new entity exactly one owning role unless several roles genuinely write the same kind of record.

This is a tripwire against an agent writing outside its remit, not security.

## Schema evolution

- `schema.sql` is always the complete current schema. It ends with `PRAGMA user_version = <n>`.
- A fresh database gets `schema.sql`. An existing one at version `k` gets `migrations/<k+1>.sql` … `migrations/<n>.sql`, in order, in one transaction. Each migration ends by setting `user_version` to its own number.
- Every schema change is a migration and an edit to `schema.sql` that leaves them equivalent: a fresh database and an upgraded one must end up the same.
- Prefer additive changes. Views are dropped and recreated freely; tables are not.
- Statements are split with `sqlite3.complete_statement`, so trigger bodies are fine. Don't open your own transactions in a script.

## Conventions

- Tables are singular `snake_case` nouns; views are `v_<noun>`.
- Keys are `id INTEGER PRIMARY KEY`; references are `<entity>_id`.
- Timestamps are ISO-8601 UTC text with milliseconds, defaulted by the schema; `update.py` refreshes `updated_at`.
- Booleans are `INTEGER` 0/1 with a `CHECK`.
- JSON lives only in `context` (and in view output), checked with `json_valid`.
- Every per-session table has an index starting with `session_id`, usually `(session_id, <state column>)`.

## Retention

Rows are kept after a run completes, so the conductor can audit it. They go only when the conductor asks: removing a session cascades, and removing every session in a lineage retires the run. Nothing deletes on a timer.

## The database is a claim

A recovered row says what an agent believed when it wrote it. Anything that can be checked against reality (a worktree exists, a branch head equals `commit_sha`, a worktree is clean) is checked before a resumed run relies on it. Design rows so these checks are possible: record identifiers, not descriptions.
