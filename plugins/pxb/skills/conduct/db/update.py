#!/usr/bin/env python3
"""update <entity> <id> --as <role> [--session <id>] [key=value | key:=json ...]  — set columns, merge context, print the row.

Context keys merge into the existing context; `key:=null` removes one.
"""

import argparse
import json

import pxdb


def main():
    p = argparse.ArgumentParser(prog="update.py", description=__doc__)
    p.add_argument("entity")
    p.add_argument("id", type=int)
    p.add_argument("fields", nargs="*")
    p.add_argument("--as", dest="role")
    p.add_argument("--session")
    a = p.parse_args()

    conn = pxdb.connect()
    pxdb.require_entity(conn, a.entity)
    pxdb.check_owner(conn, a.entity, a.role)
    typed, context = pxdb.split_fields(conn, a.entity, pxdb.parse_fields(a.fields))
    for fixed in ("session_id", "role"):
        if fixed in typed:
            raise pxdb.Fail(f"{fixed} can't be changed")

    conn.execute("BEGIN IMMEDIATE")
    try:
        row = conn.execute(f"SELECT * FROM {a.entity} WHERE id = ?", (a.id,)).fetchone()
        if not row:
            raise pxdb.Fail(f"no {a.entity} {a.id}")
        if "role" in row.keys() and row["role"] != a.role:
            raise pxdb.Fail(f"{a.entity} {a.id} belongs to role '{row['role']}'")
        pxdb.check_in_run(conn, a.entity, row, a.session)
        merged = json.loads(row["context"])
        merged.update(context)
        typed["context"] = json.dumps({k: v for k, v in merged.items() if v is not None}, ensure_ascii=False)
        sets = ", ".join(f"{n} = ?" for n in typed) + f", updated_at = {pxdb.NOW}"
        conn.execute(f"UPDATE {a.entity} SET {sets} WHERE id = ?", [*typed.values(), a.id])
        conn.execute("COMMIT")
    except BaseException:
        conn.execute("ROLLBACK")
        raise
    pxdb.emit(pxdb.row_out(conn.execute(f"SELECT * FROM {a.entity} WHERE id = ?", (a.id,)).fetchone()))


if __name__ == "__main__":
    pxdb.run(main)
