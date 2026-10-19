#!/usr/bin/env python3
"""add <entity> --as <role> [--session <id>] [key=value | key:=json ...]  — insert a row, print it."""

import argparse
import json

import pxdb


def main():
    p = argparse.ArgumentParser(prog="add.py", description=__doc__)
    p.add_argument("entity")
    p.add_argument("fields", nargs="*")
    p.add_argument("--as", dest="role")
    p.add_argument("--session")
    a = p.parse_args()

    conn = pxdb.connect()
    pxdb.require_entity(conn, a.entity)
    pxdb.check_owner(conn, a.entity, a.role)
    typed, context = pxdb.split_fields(conn, a.entity, pxdb.parse_fields(a.fields))
    cols = pxdb.columns(conn, a.entity)

    if "session_id" in cols:
        session = pxdb.resolve_session(conn, a.session or typed.get("session_id"))
        if session is None:
            raise pxdb.Fail(f"{a.entity} needs --session")
        typed["session_id"] = session
    if "role" in cols:
        if typed.setdefault("role", a.role) != a.role:
            raise pxdb.Fail(f"role must be your own ({a.role})")

    typed["context"] = json.dumps(context, ensure_ascii=False)
    names = list(typed)
    cur = conn.execute(
        f"INSERT INTO {a.entity} ({', '.join(names)}) VALUES ({', '.join('?' for _ in names)})",
        [typed[n] for n in names],
    )
    pxdb.emit(pxdb.row_out(conn.execute(f"SELECT * FROM {a.entity} WHERE id = ?", (cur.lastrowid,)).fetchone()))


if __name__ == "__main__":
    pxdb.run(main)
