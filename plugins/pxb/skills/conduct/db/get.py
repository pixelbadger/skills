#!/usr/bin/env python3
"""get <entity|view> [id] [--session <id>] [--limit N] [key=value ...]  — read rows as JSON. Any role.

Filters match a column, or a context key when there is no such column.
--session covers the session's whole lineage.
"""

import argparse

import pxdb


def main():
    p = argparse.ArgumentParser(prog="get.py", description=__doc__)
    p.add_argument("name")
    p.add_argument("filters", nargs="*")
    p.add_argument("--session")
    p.add_argument("--limit", type=int)
    a = p.parse_args()

    conn = pxdb.connect()
    kind = pxdb.relation_kind(conn, a.name)
    if kind is None:
        raise pxdb.Fail(f"no entity or view: {a.name}")
    cols = pxdb.columns(conn, a.name)

    filters = list(a.filters)
    if filters and filters[0].isdigit():
        filters[0] = f"id={filters[0]}"

    where, params = [], []
    for key, value in pxdb.parse_fields(filters):
        if key in cols:
            where.append(f"{key} IS ?")
            # View expression columns have no affinity, so '1' would never equal 1.
            if isinstance(value, str) and value.lstrip("-").isdigit():
                value = int(value)
        elif "context" in cols:
            where.append("json_extract(context, ?) IS ?")
            params.append(f"$.{key}")
        else:
            raise pxdb.Fail(f"{a.name} has no column {key}")
        params.append(value)

    session = pxdb.resolve_session(conn, a.session)
    if session is not None:
        if kind == "view" and "session_id" in cols:
            where.append("session_id = ?")
        elif "session_id" in cols:
            where.append("session_id IN (SELECT ancestor_id FROM v_lineage WHERE session_id = ?)")
        elif a.name == "session":
            where.append("id IN (SELECT ancestor_id FROM v_lineage WHERE session_id = ?)")
        else:
            raise pxdb.Fail(f"{a.name} is not per-session")
        params.append(session)

    sql = f"SELECT * FROM {a.name}"
    if where:
        sql += " WHERE " + " AND ".join(where)
    if "id" in cols:
        sql += " ORDER BY id"
    if a.limit:
        sql += f" LIMIT {int(a.limit)}"
    pxdb.emit([pxdb.row_out(r) for r in conn.execute(sql, params)])


if __name__ == "__main__":
    pxdb.run(main)
