# HTML Run Report

Read only when the conductor asks for an HTML report. It presents the completion report as a scroll-driven page: a pinned "flight recorder" timeline of every agent above a chronological narrative of the run. Write the Markdown completion report first; the HTML report retells it with timings and evidence.

Writing the report is a scratch-file action, not mutation.

## 1. Gather the facts

Every number and time on the page comes from a source below. If something wasn't measured, leave it out (or `null` in the data); never estimate.

| Fact | Source |
|---|---|
| Request, phases, decisions, spend, lessons | `run.md`, `spec.md`, `streams.md`, `defects.md` |
| Each worker's start and end | Modification time of its `dispatches/` file (start) and `reports/` file (end): `stat -c '%y' <file>` (`stat -f '%Sm'` on macOS). A re-run dispatched as a message to the same executor has its own dispatch number |
| Phase boundaries and event times | The orchestrator's transcripts (one per id in `Sessions:`, as JSONL under `~/.claude/projects/<project>/`): the timestamps of the edits that changed `Phase:` in `run.md`, of SPEC LOCK, of spec amendments, and of defects being ledgered |
| Waits on the conductor | The same transcripts: from the message that asked the conductor something to the conductor's reply. Mark a wait blocking when no worker was running |
| Tokens | Each agent's context size at handover: the last assistant message's `usage` (input + cache read + cache creation tokens) in its transcript. Subagent transcripts are stored with the session where the runtime keeps them; if they aren't available, use `null` |
| Tests, E2E results, screenshots | Test executor and E2E handovers in `reports/`, and the evidence dirs |

Build the report before the evidence dirs are deleted.

## 2. Fill the template

Copy `reference/html-report-template.html` to `<run directory>/report.html` and replace each placeholder. Confirm no `{{` remains.

| Placeholder | Content |
|---|---|
| `TITLE` | A short name for the page, e.g. `<Repository> <change> — Conduct run` |
| `EYEBROW` | `Conduct · run report · <dates> · times UTC` |
| `HEADLINE` | The outcome, in one sentence |
| `LEDE` | The request in plain words, how the run went at a glance, and "Scroll, and the recorder above replays the run." |
| `FACTS` | 5–8 `<div><dt>…</dt><dd>…<small>…</small></dd></div>` cells: wall clock (against the budget), waiting on the conductor, subagents and dispatches (against the budget), fix rounds, tests held green (base → final), conductor decisions, and one run-specific fact |
| `CHAPTERS` | The narrative (below) |
| `TOKENS_NOTE` | `<p>` paragraphs: where the token figures come from, and what they exclude |
| `TIME_NOTE` | `<p>` paragraphs: wall clock, total worker time, peak concurrency, where the rest went, and what the conductor waits were |
| `LEFT_FOR_LATER` | One `<div><b>…</b>…</div>` per residual risk from the completion report |
| `RUN_DATA` | The run data JSON (below) |

## 3. Narrative

One `<section class="ch" data-t="<ISO timestamp>">` per chapter, in time order, usually one per phase or fix round. `data-t` is when the chapter starts; the recorder's playhead interpolates between chapters as the reader scrolls.

```html
<section class="ch" data-t="2026-10-16T22:40:00Z">
  <p class="ch-time">22:40 – 22:47 <em>Preflight · research</em></p>
  <h2>What this chapter established</h2>
  <p>Prose. Name tiers with <span class="tier o">orchestrator</span>, <span class="tier j">judgement-tier</span>, <span class="tier m">mechanical-tier</span>.</p>

  <div class="finding" data-t="2026-10-16T23:20:00Z">
    <p class="tag">Defect D1 · 23:20</p>
    <h3>The defect, as observed</h3>
    <p>Cause, and the evidence that showed it.</p>
    <ol class="steps">
      <li><span>23:24</span>What the fix changed.</li>
      <li><span>23:30</span>The evidence that closed it.</li>
    </ol>
  </div>
</section>
```

- **Findings.** Plain `finding` for defects, verification defects and CI failures (tag `Defect D1`, `Verification defect V1`, `CI red`). Add `ask` for conductor input and spec amendments (`Conductor input`, `Spec amendment A1`), and `good` for the delivery (`Delivered · merged HH:MM`).
- **Gallery.** When screenshots or other visual output are acceptance evidence, add a `<div class="gallery">` of `<figure><img src="data:…" alt="…"><figcaption><b>…</b>…<span>source · HH:MM</span></figcaption></figure>`. Embed the images as data URIs, only those that are evidence, and keep the page under 10 MB.
- **Voice.** Plain, past tense, specific: what happened, what it cost, and what evidence settled it. Use Conduct's terms: conductor, orchestrator, judgement and mechanical tiers, stream, SPEC LOCK, fix round.

## 4. Run data

```json
{
  "start": "2026-10-16T22:38:00Z",
  "end": "2026-10-17T00:12:00Z",
  "tiers": {
    "o": { "name": "Orchestrator", "model": "Opus 5.5" },
    "j": { "name": "Judgement tier", "model": "Sonnet 5.5" },
    "m": { "name": "Mechanical tier", "model": "Haiku 5.5" }
  },
  "orchestrator": { "start": "2026-10-16T22:40:00Z", "end": "2026-10-17T00:09:00Z", "tokens": 496200 },
  "agents": [
    { "tier": "m", "label": "Baseline suite", "phase": "Baseline",
      "segments": [["2026-10-16T22:41:00Z", "2026-10-16T22:45:00Z"]], "tokens": 63907, "counted": false }
  ],
  "phases": [{ "name": "Preflight", "start": "2026-10-16T22:40:00Z", "end": "2026-10-16T22:42:00Z" }],
  "waits": [{ "start": "2026-10-16T22:47:00Z", "end": "2026-10-16T22:53:00Z", "label": "spec approval", "blocking": true }],
  "marks": [{ "t": "2026-10-16T22:53:00Z", "label": "SPEC LOCK", "kind": "event" },
            { "t": "2026-10-16T23:20:00Z", "label": "D1", "kind": "flag" }]
}
```

- `start` and `end` bound the chart; leave a minute or two either side of the orchestrator's span.
- `tiers` take their models from SKILL.md's Tiers table.
- One `agents` entry per worker: `tier` is `j` or `m`; `segments` lists each run of it (several for an executor re-run by message); `counted` is `false` for pre-lock and other uncounted dispatches.
- `phases` cover the run without gaps, named as the reader will see them (e.g. Preflight, Specify, Plan, Implement, Integrate, Fix, Deliver).
- `marks`: `kind` `flag` for defects and failures, `event` for everything else.
- All times are ISO 8601 UTC.

## 5. Check and hand over

1. Confirm the JSON parses and no `{{` remains.
2. If a browser is available (e.g. Playwright with the pre-installed Chromium), load the page at 390 px and 1280 px wide, confirm there are no console errors, and that scrolling to the end moves the playhead to the end of the run.
3. Give the conductor the path. If the session can publish pages, offer to publish it.
