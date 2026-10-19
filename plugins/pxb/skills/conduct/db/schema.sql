-- Conduct run database: the full current schema.
-- Applied to a fresh database. Existing databases are upgraded by migrations/<n>.sql.
-- Read SQL-DEVELOPMENT.md before changing anything here.

-- Ownership: which roles may add, update and remove each entity's rows.
-- The write scripts check `--as <role>` against this table. A tripwire, not security.
CREATE TABLE IF NOT EXISTS entity_owner (
  entity TEXT PRIMARY KEY,
  owners TEXT NOT NULL  -- comma-separated roles
);

INSERT OR REPLACE INTO entity_owner (entity, owners) VALUES
  ('session',  'orchestrator'),
  ('spec',     'orchestrator'),
  ('note',     'orchestrator'),
  ('stream',   'orchestrator'),
  ('dispatch', 'orchestrator'),
  ('defect',   'orchestrator'),
  ('artifact', 'orchestrator'),
  ('report',   'implementor,test-executor,reviewer,e2e-executor,e2e-explorer');

-- One conduct run inside one Claude Code session. A run resumed in a later
-- session gets a new row pointing back with resumed_from; the chain is its lineage.
CREATE TABLE IF NOT EXISTS session (
  id                INTEGER PRIMARY KEY,
  claude_session_id TEXT NOT NULL,
  resumed_from      INTEGER REFERENCES session(id) ON DELETE SET NULL,
  repo              TEXT,
  branch            TEXT,  -- delivery branch
  base_sha          TEXT,
  phase             TEXT CHECK (phase IN ('preflight','specification','planning','implementation','integration','completion')),
  status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','complete','abandoned')),
  context           TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(context)),
  created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS session_claude_session_id ON session(claude_session_id);
CREATE INDEX IF NOT EXISTS session_resumed_from ON session(resumed_from);
CREATE INDEX IF NOT EXISTS session_repo_status ON session(repo, status);

-- Specification versions. context.text holds the spec; context.budget the budget.
CREATE TABLE IF NOT EXISTS spec (
  id         INTEGER PRIMARY KEY,
  session_id INTEGER NOT NULL REFERENCES session(id) ON DELETE CASCADE,
  version    INTEGER NOT NULL,
  status     TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','locked','superseded')),
  context    TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(context)),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS spec_session ON spec(session_id, version);

-- Anything else worth recovering: conductor decisions, the Environment block,
-- budget changes, side requests. kind is free text; context.text the content.
CREATE TABLE IF NOT EXISTS note (
  id         INTEGER PRIMARY KEY,
  session_id INTEGER NOT NULL REFERENCES session(id) ON DELETE CASCADE,
  kind       TEXT NOT NULL,
  context    TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(context)),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS note_session_kind ON note(session_id, kind);

-- The stream ledger.
CREATE TABLE IF NOT EXISTS stream (
  id         INTEGER PRIMARY KEY,
  session_id INTEGER NOT NULL REFERENCES session(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  tier       TEXT CHECK (tier IN ('judgement','mechanical')),
  state      TEXT NOT NULL DEFAULT 'blocked' CHECK (state IN ('blocked','running','ready','accepted','rejected','superseded')),
  round      INTEGER NOT NULL DEFAULT 1,
  branch     TEXT,
  worktree   TEXT,
  commit_sha TEXT,  -- the accepted commit
  context    TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(context)),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS stream_session_state ON stream(session_id, state);

-- Every subagent dispatch; worker is the role dispatched. Counts towards spend unless pre_lock.
-- context.brief holds the filled brief so a resumed run can re-dispatch it unchanged.
CREATE TABLE IF NOT EXISTS dispatch (
  id         INTEGER PRIMARY KEY,
  session_id INTEGER NOT NULL REFERENCES session(id) ON DELETE CASCADE,
  worker     TEXT NOT NULL CHECK (worker IN ('implementor','test-executor','reviewer','e2e-executor','e2e-explorer')),
  tier       TEXT CHECK (tier IN ('judgement','mechanical')),
  stream_id  INTEGER REFERENCES stream(id) ON DELETE SET NULL,
  round      INTEGER,
  status     TEXT NOT NULL DEFAULT 'running' CHECK (status IN ('running','done','abandoned')),
  pre_lock   INTEGER NOT NULL DEFAULT 0 CHECK (pre_lock IN (0,1)),
  context    TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(context)),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS dispatch_session_status ON dispatch(session_id, status);
CREATE INDEX IF NOT EXISTS dispatch_stream ON dispatch(stream_id);

-- A worker's handover, written by the worker itself. context.handover holds it verbatim.
CREATE TABLE IF NOT EXISTS report (
  id          INTEGER PRIMARY KEY,
  session_id  INTEGER NOT NULL REFERENCES session(id) ON DELETE CASCADE,
  dispatch_id INTEGER NOT NULL REFERENCES dispatch(id) ON DELETE CASCADE,
  role        TEXT NOT NULL,  -- the writer: a column named role always records the --as role
  verdict     TEXT,
  commit_sha  TEXT,  -- the commit produced (implementor) or tested (executors, reviewers)
  context     TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(context)),
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS report_dispatch ON report(dispatch_id);
CREATE INDEX IF NOT EXISTS report_session ON report(session_id);

-- A report belongs to its dispatch: same session, same role.
DROP TRIGGER IF EXISTS report_matches_dispatch;
CREATE TRIGGER report_matches_dispatch
BEFORE INSERT ON report
WHEN NOT EXISTS (SELECT 1 FROM dispatch d
                 WHERE d.id = NEW.dispatch_id AND d.session_id = NEW.session_id AND d.worker = NEW.role)
BEGIN
  SELECT RAISE(ABORT, 'report must match its dispatch''s session and worker role');
END;

-- The defect ledger. context holds criterion, evidence, root cause, required change.
CREATE TABLE IF NOT EXISTS defect (
  id         INTEGER PRIMARY KEY,
  session_id INTEGER NOT NULL REFERENCES session(id) ON DELETE CASCADE,
  code       TEXT NOT NULL,  -- the ledger ID, e.g. D3
  class      TEXT CHECK (class IN ('implementation','missing','verification','documentation','specification')),
  severity   TEXT,
  status     TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed','escalated')),
  fix_rounds INTEGER NOT NULL DEFAULT 0,
  stream_id  INTEGER REFERENCES stream(id) ON DELETE SET NULL,
  context    TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(context)),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS defect_session_status ON defect(session_id, status);

-- The run manifest: everything this run created and may delete.
CREATE TABLE IF NOT EXISTS artifact (
  id         INTEGER PRIMARY KEY,
  session_id INTEGER NOT NULL REFERENCES session(id) ON DELETE CASCADE,
  kind       TEXT NOT NULL CHECK (kind IN ('worktree','branch','build','evidence','scratch')),
  path       TEXT NOT NULL,  -- filesystem path, or branch name
  status     TEXT NOT NULL DEFAULT 'live' CHECK (status IN ('live','removed')),
  context    TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(context)),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS artifact_session_status ON artifact(session_id, status);

-- Views ----------------------------------------------------------------------
-- Every view that answers "for a run" exposes session_id as the *requesting*
-- session and covers its whole lineage, so `get <view> --session <id>` works
-- the same from the first session of a run or the fifth.

-- Each session paired with itself and every session it was resumed from.
DROP VIEW IF EXISTS v_lineage;
CREATE VIEW v_lineage AS
WITH RECURSIVE chain(session_id, ancestor_id, depth) AS (
  SELECT id, id, 0 FROM session
  UNION ALL
  SELECT c.session_id, s.resumed_from, c.depth + 1
  FROM chain c JOIN session s ON s.id = c.ancestor_id
  WHERE s.resumed_from IS NOT NULL AND c.depth < 100
)
SELECT session_id, ancestor_id, depth FROM chain;

-- One row per run: its latest session (the one nothing was resumed from).
-- Use it to find the run to resume: get v_runs repo=<path> status=active
DROP VIEW IF EXISTS v_runs;
CREATE VIEW v_runs AS
SELECT s.id AS session_id, s.claude_session_id, s.repo, s.branch, s.base_sha,
       s.phase, s.status,
       (SELECT l.ancestor_id FROM v_lineage l WHERE l.session_id = s.id ORDER BY l.depth DESC LIMIT 1) AS root_session_id,
       (SELECT COUNT(*) FROM v_lineage l WHERE l.session_id = s.id) AS sessions,
       s.created_at, s.updated_at
FROM session s
WHERE NOT EXISTS (SELECT 1 FROM session c WHERE c.resumed_from = s.id);

-- The spec in force: the highest locked version, else the highest draft.
DROP VIEW IF EXISTS v_current_spec;
CREATE VIEW v_current_spec AS
SELECT session_id, id, version, status, text, budget, updated_at FROM (
  SELECT l.session_id, sp.id, sp.version, sp.status,
         json_extract(sp.context, '$.text') AS text,
         json_extract(sp.context, '$.budget') AS budget,
         sp.updated_at,
         ROW_NUMBER() OVER (PARTITION BY l.session_id
                            ORDER BY sp.status = 'locked' DESC, sp.version DESC, sp.id DESC) AS rn
  FROM v_lineage l JOIN spec sp ON sp.session_id = l.ancestor_id
  WHERE sp.status <> 'superseded'
) WHERE rn = 1;

-- The stream ledger, with each stream's latest report.
DROP VIEW IF EXISTS v_stream_ledger;
CREATE VIEW v_stream_ledger AS
SELECT l.session_id, st.id, st.name, st.tier, st.state, st.round,
       json_extract(st.context, '$.depends_on') AS depends_on,
       st.branch, st.worktree, st.commit_sha,
       r.verdict AS last_verdict, r.commit_sha AS last_report_sha, r.dispatch_id AS last_dispatch_id,
       json_extract(st.context, '$.concerns') AS concerns,
       st.updated_at
FROM v_lineage l
JOIN stream st ON st.session_id = l.ancestor_id
LEFT JOIN report r ON r.id = (SELECT r2.id FROM report r2 JOIN dispatch d ON d.id = r2.dispatch_id
                              WHERE d.stream_id = st.id ORDER BY r2.id DESC LIMIT 1);

DROP VIEW IF EXISTS v_open_defects;
CREATE VIEW v_open_defects AS
SELECT l.session_id, df.id, df.code, df.class, df.severity, df.status, df.fix_rounds, df.stream_id,
       json_extract(df.context, '$.criterion') AS criterion,
       json_extract(df.context, '$.required_change') AS required_change,
       df.updated_at
FROM v_lineage l JOIN defect df ON df.session_id = l.ancestor_id
WHERE df.status <> 'closed';

-- What a cleanup, or a resumed run, must account for.
DROP VIEW IF EXISTS v_live_artifacts;
CREATE VIEW v_live_artifacts AS
SELECT l.session_id, a.id, a.kind, a.path, a.created_at
FROM v_lineage l JOIN artifact a ON a.session_id = l.ancestor_id
WHERE a.status = 'live';

-- Dispatches not yet closed by the orchestrator. has_report = 1 means the worker
-- finished and recorded its handover, but the orchestrator never processed it.
DROP VIEW IF EXISTS v_in_flight;
CREATE VIEW v_in_flight AS
SELECT l.session_id, d.id, d.worker, d.tier, d.stream_id, d.round,
       EXISTS (SELECT 1 FROM report r WHERE r.dispatch_id = d.id) AS has_report,
       d.created_at
FROM v_lineage l JOIN dispatch d ON d.session_id = l.ancestor_id
WHERE d.status = 'running';

-- The spend line.
DROP VIEW IF EXISTS v_spend;
CREATE VIEW v_spend AS
SELECT s.id AS session_id,
       (SELECT COUNT(*) FROM v_lineage l JOIN dispatch d ON d.session_id = l.ancestor_id
        WHERE l.session_id = s.id AND d.pre_lock = 0) AS subagents,
       (SELECT COUNT(*) FROM v_lineage l JOIN dispatch d ON d.session_id = l.ancestor_id
        WHERE l.session_id = s.id AND d.pre_lock = 1) AS pre_lock_subagents,
       (SELECT COUNT(*) FROM v_lineage l JOIN dispatch d ON d.session_id = l.ancestor_id
        WHERE l.session_id = s.id AND d.pre_lock = 0 AND d.worker = 'implementor') AS implementor_dispatches,
       (SELECT MAX(d.round) FROM v_lineage l JOIN dispatch d ON d.session_id = l.ancestor_id
        WHERE l.session_id = s.id) AS rounds,
       (SELECT MIN(r.created_at) FROM v_lineage l JOIN session r ON r.id = l.ancestor_id
        WHERE l.session_id = s.id) AS started_at,
       (SELECT budget FROM v_current_spec c WHERE c.session_id = s.id) AS budget
FROM session s;

-- Everything a fresh orchestrator needs to continue a run, one row per item.
-- section orders the output; body is a JSON object. resume.py renders it.
DROP VIEW IF EXISTS v_resume;
CREATE VIEW v_resume AS
SELECT l.session_id, 1 AS ord, 'session' AS section, s.id AS item_id,
       json_object('claude_session_id', s.claude_session_id, 'depth', l.depth,
                   'repo', s.repo, 'branch', s.branch, 'base_sha', s.base_sha,
                   'phase', s.phase, 'status', s.status, 'created_at', s.created_at,
                   'context', json(s.context)) AS body
FROM v_lineage l JOIN session s ON s.id = l.ancestor_id
UNION ALL
SELECT c.session_id, 2, 'spec', sp.id,
       json_object('version', sp.version, 'status', sp.status, 'context', json(sp.context))
FROM v_current_spec c JOIN spec sp ON sp.id = c.id
UNION ALL
SELECT l.session_id, 3, 'notes', n.id,
       json_object('kind', n.kind, 'created_at', n.created_at, 'context', json(n.context))
FROM v_lineage l JOIN note n ON n.session_id = l.ancestor_id
UNION ALL
SELECT sl.session_id, 4, 'streams', st.id,
       json_object('name', st.name, 'tier', st.tier, 'state', st.state, 'round', st.round,
                   'branch', st.branch, 'worktree', st.worktree, 'commit_sha', st.commit_sha,
                   'last_verdict', sl.last_verdict, 'last_report_sha', sl.last_report_sha,
                   'context', json(st.context))
FROM v_stream_ledger sl JOIN stream st ON st.id = sl.id
UNION ALL
SELECT od.session_id, 5, 'open_defects', df.id,
       json_object('code', df.code, 'class', df.class, 'severity', df.severity, 'status', df.status,
                   'fix_rounds', df.fix_rounds, 'stream_id', df.stream_id, 'context', json(df.context))
FROM v_open_defects od JOIN defect df ON df.id = od.id
UNION ALL
SELECT f.session_id, 6, 'in_flight', d.id,
       json_object('worker', d.worker, 'tier', d.tier, 'stream_id', d.stream_id, 'round', d.round,
                   'has_report', f.has_report, 'created_at', d.created_at, 'context', json(d.context))
FROM v_in_flight f JOIN dispatch d ON d.id = f.id
UNION ALL
SELECT f.session_id, 7, 'unprocessed_reports', r.id,
       json_object('dispatch_id', r.dispatch_id, 'role', r.role, 'verdict', r.verdict,
                   'commit_sha', r.commit_sha, 'context', json(r.context))
FROM v_in_flight f JOIN report r ON r.dispatch_id = f.id
UNION ALL
SELECT session_id, 8, 'live_artifacts', id,
       json_object('kind', kind, 'path', path, 'created_at', created_at)
FROM v_live_artifacts
UNION ALL
SELECT session_id, 9, 'spend', NULL,
       json_object('subagents', subagents, 'pre_lock_subagents', pre_lock_subagents,
                   'implementor_dispatches', implementor_dispatches, 'rounds', rounds,
                   'started_at', started_at)
FROM v_spend;

PRAGMA user_version = 1;
