# Spec: ntfy Action Buttons + Action Dispatcher

**Date:** 2026-06-01  
**Phase:** B — Step 1 of 3 (ntfy buttons → EA real actions → cruise agent)  
**Status:** Approved, ready for implementation

---

## Problem

The EA scanner surfaces `agent_can_do` and `agent_can_prep` actions via ntfy notifications, but acting on them requires opening a chat, typing a command, and finding the right thread. The approve/snooze/refine cycle has too much friction to be used consistently.

Additionally, the EA has no way to surface what it *needs* in order to act autonomously — making the capability-expansion loop invisible.

---

## Goals

- One-tap Approve, Snooze, and Refine from any ntfy notification
- EA surfaces capability gaps (`agent_needs`) as part of the notification body
- Refine delivers a paste-ready Claude Code prompt via follow-up ntfy
- General-purpose dispatcher architecture — reusable for future agents and automations
- Works on home WiFi immediately; works anywhere once WireGuard is set up on phone

---

## Non-goals

- Actual EA action execution (that's Phase B step 2)
- Discord control surface
- Any UI changes to the dashboard itself

---

## Prerequisites

- WireGuard client configured on phone (required for away-from-home use; not a blocker for local dev/testing)

---

## Architecture

```
EA Scanner (existing cron on Mac mini)
  └─ fires ntfy notification with 3 action buttons
       ├─ Approve ──→ POST /action {"action":"approve","id":"chat_id"}
       ├─ Snooze  ──→ POST /action {"action":"snooze","id":"chat_id","until":"YYYY-MM-DD"}
       └─ Refine  ──→ POST /action {"action":"refine","id":"chat_id"}
                            │
                    Action Dispatcher (new Flask server, launchd, port 8765)
                            │
               ┌────────────┼────────────┐
            approve       snooze       refine
        clear agent_   set cooldown_  build context
        can_do, commit  until, commit  bundle, fire
        + push          + push         follow-up ntfy
```

The action dispatcher is general-purpose. New automations register new handler functions — the server and routing layer don't change.

---

## Data Model Changes

### New field: `agent_needs`

Added to each chat entry in `dashboard-data.json`. Optional. One line describing what the agent would need to act autonomously on `agent_can_do`.

```json
{
  "agent_can_do": "Check if GitHub PR #42 merged and update dashboard status",
  "agent_can_prep": "Research keepalived IPv6 config and draft steps",
  "agent_needs": "SSH access to pihole1"
}
```

`agent_needs` is `null` when there are no known prerequisites. All existing entries default to `null`.

### Session wrap protocol update

Add `agent_needs` as a required field in the session wrap:
- `agent_needs` — one line: what the agent would need to execute `agent_can_do` autonomously, or `null`

---

## Action Dispatcher

**Location:** `~/scripts/action-dispatcher/` on Mac mini (not in the life-dashboard repo — this is infrastructure)

**File layout:**
```
~/scripts/action-dispatcher/
├── app.py           — Flask server, routing
├── handlers.py      — approve / snooze / refine logic
├── context.py       — context bundle builder for refine
├── .env             — NTFY_URL, NTFY_TOKEN, DASHBOARD_PATH, SECRET_TOKEN
└── com.mrrouser.action-dispatcher.plist  — launchd config
```

**Endpoint:**
```
POST /action
Header: Authorization: Bearer <SECRET_TOKEN>
Body:   {"action": "approve|snooze|refine", "id": "<chat_id>", "until": "<YYYY-MM-DD>"}
```

`until` is optional; used only by snooze (defaults to 7 days out if omitted).

**Security:** Shared secret token in `Authorization` header. Sufficient for home network / WireGuard. Token stored in `.env`, never hardcoded.

**Handler routing:**
```python
HANDLERS = {
    "approve": handle_approve,
    "snooze":  handle_snooze,
    "refine":  handle_refine,
}
```

New automations add a key to `HANDLERS`. Nothing else changes.

---

## Handlers

### approve
1. Read `dashboard-data.json`
2. Find chat by `id`
3. Clear `agent_can_do` (set to `null`)
4. Set `last_completed` to `"EA action approved via ntfy"`
5. Write, commit, push

*Phase B step 2 extension point:* this handler executes the action before clearing. Structure stays identical.

### snooze
1. Read `dashboard-data.json`
2. Find chat by `id`
3. Set `cooldown_until` to `until` param (or today + 7 days)
4. Write, commit, push

### refine
1. Read `dashboard-data.json`
2. Find chat by `id`
3. Build context bundle from: `title`, `agent_can_do`, `agent_can_prep`, `agent_needs`, `breadcrumb`, `open_question`
4. Format as paste-ready Claude Code prompt (see below)
5. Send follow-up ntfy notification with prompt as body

**Refine prompt format:**
```
Refine EA action for "[title]".

Surfaced action: [agent_can_do]
Needs:          [agent_needs]
Prep available: [agent_can_prep]
Context:        [breadcrumb]

Work with me to refine this action or provision what the agent needs.
```

Fields are omitted if `null`. User copies prompt, opens Claude Code in `~/repos/life-dashboard`, pastes.

---

## Updated EA Scanner Notification Format

The scanner's ntfy call is updated to include action buttons and surface `agent_needs` in the body.

**Notification body (when `agent_needs` is set):**
```
Title: EA: [chat title]
Body:  I can do: [agent_can_do]
       Needs:    [agent_needs]
       Tap Refine to set it up, or Approve/Snooze.

Actions: [Approve] [Snooze] [Refine]
```

**Notification body (when `agent_needs` is null):**
```
Title: EA: [chat title]
Body:  I can do: [agent_can_do]

Actions: [Approve] [Snooze] [Refine]
```

ntfy `http` action button format (per button):
```
action=http, label=Approve, url=http://<MAC_MINI_IP>:8765/action,
method=POST, body={"action":"approve","id":"<chat_id>"},
headers.Authorization=Bearer <SECRET_TOKEN>
```

MAC_MINI_IP and SECRET_TOKEN are read from the scanner's `.env`.

---

## Reusability

This dispatcher is the foundation for Phase B steps 2 and 3:

| Step | What gets added |
|------|----------------|
| EA real actions | `approve` handler executes `agent_can_do` via Claude Code subprocess |
| Cruise/trip agent | New handler registered in `HANDLERS` |
| Any future agent | Same pattern — register a handler, done |

---

## Out of scope for this spec

- Actual execution of `agent_can_do` (Phase B step 2)
- WireGuard phone setup (prerequisite, separate task)
- Changes to `index.html` or dashboard UI

---

## Open questions

- What port is currently in use on Mac mini? Confirm 8765 is free before implementation.
- Where does the EA scanner script currently live on the Mac mini? (Needed to know what file to update for action buttons.)
