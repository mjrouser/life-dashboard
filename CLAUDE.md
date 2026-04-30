# CLAUDE.md — life-dashboard

Project-specific guidance for Claude Code. The global `~/.claude/CLAUDE.md` applies alongside this file — this file adds context specific to this project. Don't repeat global rules here.

Created: 2026-04-29

---

## What This Project Is

A personal cross-project status dashboard hosted on GitHub Pages. Answers "what should I touch next, given my current energy?" Two files: `index.html` (static, no build step) + `dashboard-data.json` (the data layer). Claude Code updates the JSON at the end of sessions; the page fetches it fresh on load.

---

## Target Platform

**Dev:** MacBook Pro 2018
**Deploy:** GitHub Pages — served from `main` branch root

---

## Stack & Key Dependencies

- Vanilla HTML/CSS/JS — no framework, no build step, no npm
- IBM Plex Sans + IBM Plex Mono loaded from Google Fonts
- `dashboard-data.json` fetched at runtime via `fetch()`

---

## Paid APIs & Cost Model

None.

---

## How to Run

**Local dev (preview in browser without GitHub Pages):**
```bash
cd ~/repos/life-dashboard
python3 -m http.server 8080
# then open http://localhost:8080
```
Note: you must use a local server (not `file://`) because the page fetches `dashboard-data.json` via `fetch()`.

**Deploy:**
```bash
git add dashboard-data.json index.html
git commit -m "your message"
git push
```
GitHub Pages serves automatically from `main` branch root. No build step needed.

**Test:**
Manual smoke test — open in browser, verify all sections render, check filter pills, check dark mode via DevTools.

---

## Project Structure

```
life-dashboard/
├── index.html           — single-file dashboard (HTML + CSS + JS)
├── dashboard-data.json  — data layer, updated by Claude Code each session
└── CLAUDE.md            — this file
```

---

## Session Wrap Protocol

At the end of any session that touches a project tracked in this dashboard, update `dashboard-data.json` for the relevant chat entry:

**Always update:**
- `next_step` — the single next action for this chat
- `breadcrumb` — brief context so the user or Claude can re-enter fast
- `updated` — today's date (YYYY-MM-DD)

**Update if changed:**
- `status` — if the chat's status changed (e.g. moved from `active-in-progress` to `shipped`)
- `energy` — energy level the next step requires (`high` | `medium` | `low`)

**Update `today` array** — add/remove `chat_id` entries to reflect what's pickable in the next session (max 3 items).

**Update `meta.last_updated`** — ISO 8601 timestamp.

After updating the JSON, commit and push:
```bash
git add dashboard-data.json
git commit -m "Session wrap: <brief summary>"
git push
```

---

## Known Gotchas & Constraints

- `fetch()` won't work from `file://` — always use `python3 -m http.server 8080` for local preview.
- The `today` array references chat IDs — if a chat is renamed or removed, update `today` to avoid broken references (the render code silently skips missing IDs, but stale entries are noise).
- Dark mode is `prefers-color-scheme: dark` only — no manual toggle. Test both modes via browser DevTools.

---

## Current Status & Next Steps

**Status:** v1 live — dashboard built and deployed to GitHub Pages

**Current focus:**
Session wrap integration — update `dashboard-data.json` at end of each project session
