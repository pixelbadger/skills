# Run database: script API

Conduct records what a recovery needs in a SQLite database: enough for a fresh orchestrator, in a new Claude Code session, to pick up a run where the last one stopped. This file is the reference for the scripts that read and write it. Why it is shaped this way is in [SQL-DEVELOPMENT.md](SQL-DEVELOPMENT.md).

## Basics

- **Scripts.** Five, in this directory, all Python 3.8+ standard library only. Invoke them as `python3 <skill dir>/db/<script>.py …` (`python` or `py -3` where that's the interpreter's name).

  | Script | Does | Who |
  |---|---|---|
  | `add.py <entity> …` | insert a row | the entity's owner |
  | `update.py <entity> <id> …` | set columns, merge context | the entity's owner |
  | `remove.py <entity> <id> …` | delete a row | the entity's owner |
  | `get.py <entity\|view> …` | read rows | anyone |
  | `resume.py <session>` | everything needed to continue a run | anyone |

- **Location.** `$PXB_CONDUCT_DB` if set, else `$CLAUDE_CONFIG_DIR/pxb/conduct.db`, else `~/.claude/pxb/conduct.db`. One database per machine holds every run; rows carry their repository path. The first call creates it and applies the schema.
- **Output.** JSON on stdout: the row for `add` and `update`, an array of rows for `get`. A row's `context` comes back as an object.
- **Exit codes.** `0` success; `2` usage or guard error (message on stderr, starting `error:`); `3` SQLite error, including constraint and trigger failures (`sqlite error:`).
- **Concurrency.** WAL mode with a 10 s busy timeout. Parallel workers can write at once.

## Fields

Every write takes fields as arguments after the entity (and id):

| Form | Meaning |
|---|---|
| `key=value` | a string |
| `key:=json` | a JSON value: `round:=2`, `pre_lock:=1`, `depends_on:='["api"]'`, `x:=null` |
| `key=@path` | the contents of a file |
| `key=@-` | stdin (a heredoc, for long text) |
| `key=@@text` | the literal string `@text` |

**Typed columns versus context.** If `key` is one of the entity's columns (below), the value goes into that column. Any other key goes into the row's `context`, a JSON object. So you never need to know which is which to record something; the schema decides. `context:={…}` merges a whole object into context at once.

On `update`, context keys merge into the existing context: keys you don't mention are kept, and `key:=null` removes one. A column set to `:=null` becomes NULL.

## Sessions

A **session** row is one conduct run inside one Claude Code session. Its `claude_session_id` holds Claude Code's session id. When a run is resumed in a later Claude Code session, the new session row points back with `resumed_from`. The chain of sessions is the run's **lineage**.

Wherever a script takes `--session <ref>`, `<ref>` is either a session row id (`7`) or a Claude Code session id, which resolves to the latest session row carrying it. Reads with `--session` cover the whole lineage: rows recorded by earlier sessions of the same run are included. On `update` and `remove`, `--session` is a check: the row must belong to that session's lineage, or the write is refused. `add session` ignores it.

## Roles and ownership

Every write needs `--as <role>`. Roles: `orchestrator`, `implementor`, `test-executor`, `reviewer`, `e2e-executor`, `e2e-explorer`.

Each entity has owning roles, held in the `entity_owner` table. A write by any other role is refused. Where an entity has a `role` column, it records the writer: `add` fills it from `--as`, and `update`/`remove` refuse rows written by another role.

This is a tripwire that keeps each role to its own records. It is not security: anyone can pass any `--as`.

## Entities

Every entity row also has `id` (integer), `context` (JSON object), `created_at` and `updated_at` (ISO-8601 UTC, set automatically). Every entity but `session` has `session_id`, filled from `--session`, which a write requires. Removing a session removes everything recorded under it.

| Entity | Owner | Typed columns | Context, by convention |
|---|---|---|---|
| `session` | orchestrator | `claude_session_id` (required), `resumed_from`, `repo`, `branch` (delivery branch), `base_sha`, `phase` (`preflight`, `specification`, `planning`, `implementation`, `integration`, `completion`), `status` (`active`\*, `complete`, `abandoned`) | `request`: the conductor's change request |
| `spec` | orchestrator | `version` (required), `status` (`draft`\*, `locked`, `superseded`) | `text`: the specification; `budget` |
| `note` | orchestrator | `kind` (required, free text: `decision`, `environment`, `side-request`, …) | `text`; for a decision, `question` too |
| `stream` | orchestrator | `name` (required), `tier` (`judgement`, `mechanical`), `state` (`blocked`\*, `running`, `ready`, `accepted`, `rejected`, `superseded`), `round` (1\*), `branch`, `worktree`, `commit_sha` (the accepted commit) | `objective`, `depends_on` (array of stream names), `concerns` |
| `dispatch` | orchestrator | `worker` (the role dispatched, required), `tier`, `stream_id`, `round`, `status` (`running`\*, `done`, `abandoned`), `pre_lock` (0\*/1) | `brief`: the filled brief; `purpose` |
| `report` | implementor, test-executor, reviewer, e2e-executor, e2e-explorer | `dispatch_id` (required), `role` (from `--as`), `verdict`, `commit_sha` (produced or tested) | `handover`: the worker's handover, verbatim |
| `defect` | orchestrator | `code` (the ledger ID, required), `class` (`implementation`, `missing`, `verification`, `documentation`, `specification`), `severity`, `status` (`open`\*, `closed`, `escalated`), `fix_rounds` (0\*), `stream_id` | `criterion`, `evidence`, `root_cause`, `required_change` |
| `artifact` | orchestrator | `kind` (`worktree`, `branch`, `build`, `evidence`, `scratch`, required), `path` (path or branch name, required), `status` (`live`\*, `removed`) | |

\* default.

A report must match its dispatch: the same session, and `--as` equal to the dispatch's `worker`. Otherwise the insert fails (exit 3).

Report verdicts by role: implementor `done` or `stopped`; test executor and E2E executor `pass`, `fail` or `blocked`; reviewer `findings` or `clean`; E2E explorer `findings`, `clean` or `blocked`.

## Views

Standard queries are views; read them with `get.py <view> --session <ref>`. In every view but `v_runs` and `v_lineage`, `session_id` is the session asking, and the rows cover its whole lineage.

| View | Rows |
|---|---|
| `v_runs` | one per run: its latest session, with `root_session_id` and `sessions` (lineage length). Find a run to resume with `get.py v_runs repo=<path> status=active` |
| `v_lineage` | each session paired with itself and every session it was resumed from (`ancestor_id`, `depth`) |
| `v_current_spec` | the spec in force: the highest locked version, else the highest draft |
| `v_stream_ledger` | the stream ledger, with each stream's latest report verdict and commit |
| `v_open_defects` | defects not `closed` |
| `v_live_artifacts` | the run manifest: artifacts not yet removed |
| `v_in_flight` | dispatches still `running`; `has_report` = 1 if the worker finished and recorded its handover but the orchestrator never processed it |
| `v_spend` | `subagents` (excluding pre-lock), `pre_lock_subagents`, `implementor_dispatches`, `rounds`, `started_at`, `budget` |
| `v_resume` | everything above, one row per item: `section`, `ord`, `item_id`, `body` (JSON) |

## Commands

### add

```text
add.py <entity> --as <role> [--session <ref>] [field ...]
```

Inserts a row and prints it, `id` included.

```bash
python3 db/add.py session --as orchestrator claude_session_id=$SID repo="$PWD" phase=preflight request=@request.txt
python3 db/add.py stream --as orchestrator --session $SID name=api tier=judgement depends_on:='["schema"]'
python3 db/add.py report --as implementor --session 7 dispatch_id:=12 verdict=done commit_sha=3f2a9c1 handover=@- <<'EOF'
STREAM api — swarm/api
...
EOF
```

### update

```text
update.py <entity> <id> --as <role> [--session <ref>] [field ...]
```

Sets columns, merges context, refreshes `updated_at`, and prints the row. `session_id` and `role` can't be changed.

```bash
python3 db/update.py stream 3 --as orchestrator state=accepted commit_sha=3f2a9c1
python3 db/update.py defect 5 --as orchestrator fix_rounds:=2 root_cause="lock taken after publish"
```

### remove

```text
remove.py <entity> <id> --as <role> [--session <ref>]
```

Deletes one row. Removing a session deletes everything recorded under it, so only do it when the conductor asks for a run's record to go. To retire a whole run, remove every session in its lineage (`get.py session --session <latest>`).

### get

```text
get.py <entity|view> [<id>] [--session <ref>] [--limit N] [key=value ...]
```

Prints matching rows, in id order where there is an id. A filter matches a column, or a context key if there's no column by that name. `get.py stream 3` reads one row by id.

```bash
python3 db/get.py v_stream_ledger --session $SID
python3 db/get.py v_in_flight --session $SID has_report=1
python3 db/get.py note --session $SID kind=decision
```

### resume

```text
resume.py <session ref> [--json]
```

Renders `v_resume` for the session as Markdown, by section: the lineage, the spec in force, notes and decisions, the stream ledger, open defects, dispatches in flight, reports not yet processed, the live run manifest, and spend. Long context text (the spec, briefs, handovers) is printed in blocks. `--json` prints the same as data.

What the output records is a claim, not proof. SKILL.md's **Recovery** section says how a resumed run verifies it.
