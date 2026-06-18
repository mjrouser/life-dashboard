# Workday Focus Todo App — Design Spec
_2026-06-17_

## Overview

A standalone daily work-focus tool. Captures a full backlog across four fixed categories, lets you pin the items that matter today, then collapses to show only those items. Replaces a sticky-note system that was high-friction to maintain.

**Not part of life-dashboard.** The dashboard tracks long-running personal projects; this tool manages day-to-day work tasks. Different purpose, different cadence, different UX pattern (write-heavy, kept open all day). They share design tokens so they feel like the same system.

---

## Architecture

```
Browser (desktop + phone via WireGuard)
        ↓ HTTP
Python Flask server (Mac Mini, always-on, macOS Monterey)
        ↓
SQLite database (single file on Mac Mini disk)
```

- Flask serves both the HTML page and a JSON API
- SQLite is local to the server — no network DB, no extra process
- No authentication — WireGuard handles access control
- Runs as a launchd service so it survives Mac Mini reboots
- Single repo, separate from life-dashboard

---

## Data Model

One table: `todos`

| Column | Type | Notes |
|--------|------|-------|
| `id` | integer | primary key, autoincrement |
| `category` | text | `sales`, `delivery`, `work_admin`, `personal` |
| `text` | text | todo content |
| `done` | boolean | default false |
| `pinned` | boolean | default false — surfaced in focus mode |
| `position` | integer | sort order within category, updated on drag-and-drop |
| `created_at` | timestamp | auto-set on insert |
| `completed_at` | timestamp | nullable, set when done is marked true |

**Categories are fixed** — no category table needed.

**Pinning is unrestricted** — any number of items from any category can be pinned. No per-category limit. Focus mode shows whatever is pinned, grouped by category.

**Completed items are retained** — hidden by default, visible via a "show completed" toggle. No hard deletes.

---

## API

All responses are JSON. Errors return `{"error": "message"}`.

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/` | Serves the HTML page |
| `GET` | `/api/todos` | All todos, grouped by category |
| `POST` | `/api/todos` | Add a new todo |
| `PATCH` | `/api/todos/<id>` | Update text, done, pinned, or position (including drag-and-drop reorder) |
| `DELETE` | `/api/todos/<id>` | Remove a todo |

No pagination. This is a personal tool with a manageable number of todos.

---

## UI / Layout

### Two modes, one toggle button

**Planning mode** (default on load):
- 4 columns side-by-side on desktop, stacked on mobile
- Each column shows its full backlog for that category
- Drag-and-drop to reorder items within a column (sets priority order)
- Click to pin/unpin any item — pinned items get a visual highlight
- Add new todos inline at the bottom of each column
- "Show completed" toggle reveals done items in a muted style

**Focus mode:**
- Backlog hides — only pinned items are visible, grouped by category
- Categories with no pinned items don't appear
- If nothing is pinned, shows a prompt to switch back to planning mode
- Toggle back to planning mode to reprioritize or add

### Mode persistence
Stored as a URL parameter (`?mode=focus`). Survives page refresh, bookmarkable. No client-side storage required.

### Drag-and-drop
Uses [SortableJS](https://sortablejs.github.io/Sortable/) (~30KB, MIT, no dependencies). Handles both mouse and touch — required for phone access. Native HTML5 DnD is excluded; it has poor touch support and is painful to implement reliably.

### Design tokens
IBM Plex Sans (400, 500) + IBM Plex Mono from Google Fonts. Same color palette as life-dashboard (light/dark via `prefers-color-scheme`). Feels like the same system without sharing code.

**Light mode:** background `#fafaf8`, surface `#ffffff`, text `#1a1a18`, borders `rgba(0,0,0,0.08)`
**Dark mode:** background `#141413`, surface `#1e1e1c`, text `#e8e8e4`, borders `rgba(255,255,255,0.08)`
**Pinned highlight:** energy-high green — light `#1d6b54` / dark `#5dcaa5`

---

## Error Handling & Logging

- Flask logs all requests to a file (not just console) — diagnosable from the Mac Mini without being at the keyboard
- Front-end shows an inline error banner if any API call fails — silent data loss is not acceptable for a task manager

---

## Testing

`pytest` for the Flask API. Test database uses SQLite in-memory so tests never touch real data.

**Coverage:**
- Happy path for each endpoint (GET all, POST, PATCH, DELETE)
- Key failure cases: todo not found (404), missing required fields (400), invalid position value
- Pinning behavior: pin an item, verify it appears in focus-mode query

No front-end automated tests in v1. Manual smoke test on desktop and phone before shipping.

---

## Out of scope (v1)

- Due dates or deadlines
- Recurring todos
- Multi-user access
- Notifications or reminders
- Search
- Any connection to life-dashboard data

---

## Deployment

- Mac Mini runs Flask via a launchd plist (auto-start on boot)
- Accessible on local network directly; accessible from phone via WireGuard
- SQLite file backed up as part of normal Mac Mini backup routine
