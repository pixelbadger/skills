#!/usr/bin/env python3
"""resume <session> [--json]  — everything needed to continue a run, from the v_resume view. Any role.

<session> is a session row id or a Claude Code session id.
"""

import argparse
import json

import pxdb

TITLES = {
    "session": "Sessions (lineage, newest first)",
    "spec": "Specification in force",
    "notes": "Notes and decisions",
    "streams": "Stream ledger",
    "open_defects": "Open defects",
    "in_flight": "Dispatches in flight",
    "unprocessed_reports": "Reports not yet processed",
    "live_artifacts": "Live artifacts (run manifest)",
    "spend": "Spend",
}


def is_long(value):
    return isinstance(value, str) and ("\n" in value or len(value) > 120)


def render(sections):
    """One line per item; long context strings (specs, handovers, briefs) as text blocks below it."""
    out = []
    for section, items in sections.items():
        out.append(f"## {TITLES.get(section, section)}\n")
        for item in items:
            body = dict(item["body"])
            context = body.pop("context", None) or {}
            long_text = {k: v for k, v in context.items() if is_long(v)}
            body.update({k: v for k, v in context.items() if k not in long_text})
            ident = f"[{item['item_id']}] " if item["item_id"] is not None else ""
            out.append(f"- {ident}" + json.dumps(body, ensure_ascii=False))
            for key, text in long_text.items():
                out.append(f"\n  {key}:\n\n```text\n{text.rstrip()}\n```\n")
        out.append("")
    return "\n".join(out)


def main():
    p = argparse.ArgumentParser(prog="resume.py", description=__doc__)
    p.add_argument("session")
    p.add_argument("--json", action="store_true")
    a = p.parse_args()

    conn = pxdb.connect()
    session = pxdb.resolve_session(conn, a.session)
    rows = conn.execute(
        "SELECT section, item_id, body FROM v_resume WHERE session_id = ?"
        " ORDER BY ord, CASE WHEN section = 'session' THEN -item_id ELSE item_id END",
        (session,),
    ).fetchall()
    sections = {}
    for r in rows:
        sections.setdefault(r["section"], []).append({"item_id": r["item_id"], "body": json.loads(r["body"])})

    if a.json:
        pxdb.emit({"session_id": session, "sections": sections})
    else:
        print(f"# Resume: session {session}\n")
        print(render(sections))


if __name__ == "__main__":
    pxdb.run(main)
