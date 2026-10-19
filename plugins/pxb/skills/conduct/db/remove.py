#!/usr/bin/env python3
"""remove <entity> <id> --as <role> [--session <id>]  — delete a row (and, for a session, everything recorded under it)."""

import argparse

import pxdb


def main():
    p = argparse.ArgumentParser(prog="remove.py", description=__doc__)
    p.add_argument("entity")
    p.add_argument("id", type=int)
    p.add_argument("--as", dest="role")
    p.add_argument("--session")
    a = p.parse_args()

    conn = pxdb.connect()
    pxdb.require_entity(conn, a.entity)
    pxdb.check_owner(conn, a.entity, a.role)
    row = conn.execute(f"SELECT * FROM {a.entity} WHERE id = ?", (a.id,)).fetchone()
    if not row:
        raise pxdb.Fail(f"no {a.entity} {a.id}")
    if "role" in row.keys() and row["role"] != a.role:
        raise pxdb.Fail(f"{a.entity} {a.id} belongs to role '{row['role']}'")
    pxdb.check_in_run(conn, a.entity, row, a.session)
    conn.execute(f"DELETE FROM {a.entity} WHERE id = ?", (a.id,))
    pxdb.emit({"removed": a.entity, "id": a.id})


if __name__ == "__main__":
    pxdb.run(main)
