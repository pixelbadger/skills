"""Shared plumbing for the conduct run database scripts. See API.md."""

import json
import os
import re
import sqlite3
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCHEMA = HERE / "schema.sql"
MIGRATIONS = HERE / "migrations"
NAME = re.compile(r"^[a-z_][a-z0-9_]*$")
NOW = "strftime('%Y-%m-%dT%H:%M:%fZ','now')"


class Fail(Exception):
    pass


def db_path():
    if os.environ.get("PXB_CONDUCT_DB"):
        return Path(os.environ["PXB_CONDUCT_DB"]).expanduser()
    base = Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude").expanduser()
    return base / "pxb" / "conduct.db"


def statements(sql):
    """Split a script into complete statements; trigger bodies stay whole."""
    buf = ""
    for line in sql.splitlines(keepends=True):
        buf += line
        if sqlite3.complete_statement(buf):
            if buf.strip():
                yield buf
            buf = ""
    if buf.strip():
        yield buf


def target_version(sql):
    m = re.search(r"PRAGMA\s+user_version\s*=\s*(\d+)", sql, re.I)
    return int(m.group(1)) if m else 0


def migrate(conn):
    schema = SCHEMA.read_text(encoding="utf-8")
    want = target_version(schema)
    if conn.execute("PRAGMA user_version").fetchone()[0] >= want:
        return
    conn.execute("BEGIN IMMEDIATE")
    try:
        have = conn.execute("PRAGMA user_version").fetchone()[0]
        if have == 0:
            scripts = [schema]
        else:
            scripts = [
                (MIGRATIONS / f"{n}.sql").read_text(encoding="utf-8")
                for n in range(have + 1, want + 1)
            ]
        for script in scripts:
            for stmt in statements(script):
                conn.execute(stmt)
        conn.execute("COMMIT")
    except BaseException:
        conn.execute("ROLLBACK")
        raise


def connect():
    path = db_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path), timeout=10, isolation_level=None)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA busy_timeout = 10000")
    conn.execute("PRAGMA foreign_keys = ON")
    migrate(conn)
    return conn


def relation_kind(conn, name):
    if not NAME.match(name):
        raise Fail(f"bad name: {name}")
    row = conn.execute(
        "SELECT type FROM sqlite_master WHERE name = ? AND type IN ('table','view')", (name,)
    ).fetchone()
    return row["type"] if row else None


def entities(conn):
    return [r["entity"] for r in conn.execute("SELECT entity FROM entity_owner ORDER BY entity")]


def require_entity(conn, name):
    if relation_kind(conn, name) != "table" or name not in entities(conn):
        raise Fail(f"unknown entity: {name} (entities: {', '.join(entities(conn))})")


def columns(conn, name):
    return [r["name"] for r in conn.execute(f"PRAGMA table_info({name})")]


def check_owner(conn, entity, role):
    if not role:
        raise Fail("writes need --as <role>")
    owners = conn.execute("SELECT owners FROM entity_owner WHERE entity = ?", (entity,)).fetchone()
    if role not in owners["owners"].split(","):
        raise Fail(f"role '{role}' may not write {entity} (owners: {owners['owners']})")


def resolve_session(conn, ref):
    """A session row id, or a Claude Code session id (its latest row)."""
    if ref is None:
        return None
    if re.fullmatch(r"\d+", ref):
        row = conn.execute("SELECT id FROM session WHERE id = ?", (int(ref),)).fetchone()
    else:
        row = conn.execute(
            "SELECT id FROM session WHERE claude_session_id = ? ORDER BY id DESC LIMIT 1", (ref,)
        ).fetchone()
    if not row:
        raise Fail(f"no session: {ref}")
    return row["id"]


def check_in_run(conn, entity, row, ref):
    """With --session on update/remove: the row must belong to that session's lineage."""
    session = resolve_session(conn, ref)
    if session is None:
        return
    own = row["id"] if entity == "session" else row["session_id"]
    if not conn.execute(
        "SELECT 1 FROM v_lineage WHERE session_id = ? AND ancestor_id = ?", (session, own)
    ).fetchone():
        raise Fail(f"{entity} {row['id']} is not part of session {ref}'s run")


def read_value(raw):
    """`@path` reads a file, `@-` reads stdin, `@@...` is a literal leading @."""
    if raw.startswith("@@"):
        return raw[1:]
    if raw == "@-":
        return sys.stdin.read()
    if raw.startswith("@"):
        return Path(raw[1:]).expanduser().read_text(encoding="utf-8")
    return raw


def parse_fields(args):
    """`key=value` (string) and `key:=json` (parsed) pairs, in order."""
    out = []
    for arg in args:
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)(:?=)(.*)$", arg, re.S)
        if not m:
            raise Fail(f"expected key=value or key:=json, got: {arg}")
        key, op, raw = m.groups()
        value = read_value(raw)
        if op == ":=":
            try:
                value = json.loads(value)
            except json.JSONDecodeError as e:
                raise Fail(f"{key}: not JSON: {e}")
        out.append((key, value))
    return out


def split_fields(conn, entity, fields):
    """Typed columns go to their column; everything else into context."""
    cols = set(columns(conn, entity)) - {"id", "context", "created_at", "updated_at"}
    typed, context = {}, {}
    for key, value in fields:
        if key == "context":
            if not isinstance(value, dict):
                raise Fail("context:= needs a JSON object")
            context.update(value)
        elif key in cols:
            if isinstance(value, (dict, list)):
                value = json.dumps(value)
            typed[key] = value
        else:
            context[key] = value
    return typed, context


def row_out(row):
    d = dict(row)
    if isinstance(d.get("context"), str):
        try:
            d["context"] = json.loads(d["context"])
        except json.JSONDecodeError:
            pass
    return d


def emit(value):
    json.dump(value, sys.stdout, indent=2, ensure_ascii=False, default=str)
    sys.stdout.write("\n")


def run(main):
    try:
        main()
    except Fail as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(2)
    except sqlite3.Error as e:
        print(f"sqlite error: {e}", file=sys.stderr)
        sys.exit(3)
