# CONTEXT.md — Personal OS reference

Read this file when you need project vision, roadmap, design tokens, data model details, or architecture context. Not loaded automatically — read on demand via `CLAUDE.md` pointer.

---

## Vision

The Personal OS is a unified, automated infrastructure for managing projects, energy, tasks, finances, communication, and life planning. The dashboard is the primary surface. Broader automation and orchestration are layered underneath.

**Target platform:**
- Dev: MacBook Pro 2018
- Deploy: GitHub Pages from `main` branch root

---

## Project structure

```
life-dashboard/
├── index.html           — single-file dashboard (HTML + CSS + JS)
├── dashboard-data.json  — data layer, updated by Claude Code each session
├── CLAUDE.md            — always-loaded session context
└── CONTEXT.md           — this file (reference, loaded on demand)
```

---

## What exists now

**Unified Dashboard (live on GitHub Pages):**
- Design is locked: card-based layout, project filter pills, Today strip, status sections
- Gold outline 3x Shipped badge
- Four dopamine features live: shipped sidebar with trophy badges + celebration animation, Pick Up Here curiosity hook card, three-color activity heatmap (active/shipped/new_idea), gap-aware return warmth

---

## Data model (`dashboard-data.json`)

- `meta` — last_updated, version
- `categories[]` — id, name, emoji
- `groups[]` — id, name, emoji, category_id (optional: vehicle_id)
- `today[]` — chat_id references for the Today strip (max 3)
- `chats[]` — id, category_id, title, status, next_step, breadcrumb, energy, updated — core fields present on all chats
- `chats[]` optional fields — group_id, deadline, start_date, last_completed, current_focus, open_question, shipped_count, celebrated, tiny_bet, notes, recurs_every, last_done, last_session_date, reference_chat, repo, blocker_type, agent_can_do, agent_can_prep, agent_needs, cooldown_until
- `activity_log[]` — date, types[] (values: "active", "shipped", "new_idea")

**Status values:** active-deadline, active-in-progress, live-has-tail, ready, parked, queued, shipped

**Energy values:** low, medium, high

---

## Design tokens (locked)

**Typography:** IBM Plex Sans (400, 500), IBM Plex Mono (labels/metadata) — Google Fonts

**Light mode:**
- Background: #fafaf8
- Surface (cards): #ffffff
- Text primary: #1a1a18
- Text secondary: #6e6e68
- Text tertiary: #a3a39d
- Borders: rgba(0,0,0,0.08), hover rgba(0,0,0,0.15)

**Dark mode:**
- Background: #141413
- Surface (cards): #1e1e1c
- Text primary: #e8e8e4
- Text secondary: #9a9a94
- Text tertiary: #6a6a64
- Borders: rgba(255,255,255,0.08), hover rgba(255,255,255,0.15)

**Accents (both modes):**
- Energy-high: light #1d6b54 / dark #5dcaa5
- Energy-medium / deadline: light #a07b28, #b85c2f / dark #e0b44a, #e0874a
- Energy-low: #7a7a74
- Shipped gold: light #a07b28 / dark #e0b44a

**Layout:**
- Container: max-width 640px, centered
- Card padding: 14px 18px
- Card gap: 8px
- Section gap: 2rem
- Card border-radius: 10px (2px left edge on deadline cards)
- Dark mode: prefers-color-scheme only, no manual toggle

---

## Design principles

1. Match tasks to energy, not just priority — answer "what can I do right now"
2. Protect from overwork — empty Today strip is permission to rest, not failure
3. Global view by default, focus mode on demand
4. Shipped items are trophies — they fade but don't disappear
5. Update loop must be near-zero friction — >2 steps = abandoned within weeks

---

## Active categories on dashboard

| Category | ID | Emoji |
|---|---|---|
| Homelab | homelab | 🖥 |
| 320 Sycamore | 320-sycamore | 🏠 |
| Personal OS | personal-os | ⚙ |
| Career | career | 💼 |
| Family | family | 👨‍👩‍👧 |
| Household admin | household-admin | 📋 |

---

## Roadmap (sequenced)

1. ~~Dashboard~~ — shipped
2. ~~Session wrap workflow~~ — shipped (manual bridge via copy-paste prompt; automation later)
3. ~~Dopamine features batch 1~~ — shipped (sidebar, curiosity hook, heatmap, return warmth)
4. **Dopamine features batch 2** — remaining to spec: variable reward (random past win on load), progress visibility (progress bars per project), completion loops (micro-tasks), tiny bets (experiment-tagged tasks)
5. **First contained automation** — Disney cruise planning agent (Oct 2026, higher urgency) as POC
6. **Discord control surface** — private server with bots for async dashboard status, approvals, triggers
7. **OpenClaw exploration** — orchestration layer, once real workflows exist to orchestrate

---

## On the horizon (no active work yet)

- **Shipped page** — separate page for completed projects. Primary: celebration/motivation. Secondary: self-promotion portfolio.
- **Finance integration** — currently a Google Sheet (manual entry is intentional). Goal: evolve from tracking to a true financial plan with reduced cognitive load. Automation augments, not replaces, hands-on inspection.
- **Disney cruise** — October 2026, higher urgency
- **Hawaii trip** — 2027, lower urgency
- **Automation targets** — reminders/follow-ups, idea capture, finance status, homelab monitoring, scheduling/planning, communication drafting, content creation (LinkedIn + income streams), technical maintenance
- **High autonomy** — acceptable once safeguards are tested, not prematurely
