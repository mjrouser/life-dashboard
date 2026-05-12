# Personal OS — Executive Assistant Design
**Date:** 2026-05-11
**Status:** Approved, ready for implementation planning

---

## Problem

The bottleneck in my life isn't capability — it's cognitive overhead. I lose threads between sessions, forget where I was, get overwhelmed seeing everything at once, and burn limited energy on orientation and decision-making instead of doing. The invisible pile — things that are technically in flight but not actively moving — is the biggest single drain.

The invisible pile stalls for four reasons, ranked by frequency:
1. **External blocker** — waiting on another person; follow-up requires effort to re-engage
2. **Fuzzy next step** — the thing exists as a concept, not as a doable action
3. **No forcing function** — no deadline, keeps getting bumped
4. **Interrupted** — got pulled away, never came back up on its own

---

## Design Principle

This is an executive assistant, not a task manager.

- A task manager organizes the pile. You still have a pile.
- An executive assistant works the pile for you. You approve or redirect.

Four rules govern every design decision:

**1. Agent-first action.** Before surfacing anything, the agent asks "what can I do to move this forward right now?" Acting is the default. Reminding is the fallback.

**2. One thing at a time, complete package.** You never see a list. You see one item: here's the situation, here's what I'd do, here's the draft. Approve, edit, or skip.

**3. Energy-matched surfacing.** The EA knows your energy model. High-energy tasks don't get surfaced at 10pm. Timing is part of the job. In Phase A this is simplified: the EA prefers lower-energy threads on weekday scans and is open to higher-energy threads on Saturday. Time-of-day awareness is Phase B+.

**4. Earned interrupts.** When something truly needs you, the EA has already done everything it can first. It surfaces the minimum viable involvement — not "handle this," but "here's the situation, here's what I've done, here's the one thing I need from you." By handling everything else, the EA earns the right to interrupt. When it does, it's signal, not noise.

---

## Architecture

### Data layer
`dashboard-data.json` is the source of truth. Every thread already has: `status`, `next_step`, `energy`, `updated`, `deadline`, `breadcrumb`.

**Three new fields added to each chat entry:**

| Field | Type | Purpose |
|---|---|---|
| `blocker_type` | `"external"` · `"self"` · `"fuzzy"` · `"deprioritized"` · `null` | Why the thread is stalled. Drives which EA behavior fires. |
| `agent_can_do` | string or null | What an agent could do on this thread right now. Set at session wrap. The EA's action hint. |
| `cooldown_until` | date or null | Set when user skips. EA won't resurface before this date. |

`blocker_type` and `agent_can_do` are added to the session wrap protocol alongside the existing fields. Same moment, same habit, two more fields.

### Agent layer — EA Scanner

Runs on schedule (see Schedule below). For each run:

1. Reads `dashboard-data.json`
2. Finds stalled threads: `updated` more than 7 days ago, or `deadline` within 7 days
3. Classifies each by `blocker_type`
4. Ranks by: deadline pressure → days stalled → energy match
5. Picks the single highest-priority item
6. Asks: **"What can I do to move this forward right now?"**

**If the EA can act:**
- Drafts follow-up email (external blocker)
- Runs resume tailoring, research session, or script (self blocker with `agent_can_do`)
- Breaks the fuzzy concept into a concrete first action (fuzzy blocker)
- Surfaces: "I can handle this. Here's what I'd do. Approve?"

**If it needs you:**
- Loads context, pulls breadcrumb, researches options, does the 80%
- Surfaces the minimum viable ask: "Here's the situation + what I've done. One thing I need from you."
- For deadline items: escalates tone, surfaces early, makes urgency visible

### Delivery

**Phase A:** ntfy.sh push notification. One item per run. Already proven infrastructure, no new setup required. Approval: open Claude Code, say "approve" or "skip."

**Phase A+:** Lightweight Flask webhook on Pi + ntfy.sh action buttons. Tap Approve on your phone, agent executes. No Claude Code session needed.

**Phase B:** Discord bot in private server. EA posts to a channel: situation summary, draft action, Approve/Skip buttons. Inline execution. Richer, the long-term approval surface.

**Phase C:** Proactive surfacing, persistent memory, expanded autonomy.

### Schedule

**MWF + Saturday** — predictable rhythm, matches natural work/life cadence. Saturday included for higher-energy weekend slot.

**Deadline override:** Any thread with a deadline within 7 days triggers immediately, regardless of schedule day. This is the safety net against things sneaking up between scan days.

Smart filtering: if no thread meets the staleness threshold on a given scan day, the EA stays quiet.

### Approval loop

| Action | Outcome |
|---|---|
| **Approve** | EA executes action. `dashboard-data.json` updated: `next_step` refreshed, `updated` set to today, `activity_log` entry added. Committed and pushed. |
| **Edit** | User tweaks draft, then approves. EA executes edited version. |
| **Skip** | `cooldown_until` set (7 days default). EA won't resurface until then. |

---

## Blocker classification

| Blocker type | EA response |
|---|---|
| **External** — waiting on another person | Draft follow-up or re-engagement email |
| **Self** — haven't found the time | Act if `agent_can_do` is set; otherwise shrink the step, energy-match, offer to add to Today strip |
| **Fuzzy** — next step unclear | Break it down into a concrete first action |
| **Deprioritized** — no deadline, keeps getting bumped | Surface with cooldown; gentle accountability |
| **Deadline approaching** | Jump the queue; do 80% first; minimum viable ask |

---

## Phase A — Build scope

What gets built to prove the loop:

1. Add `blocker_type`, `agent_can_do`, `cooldown_until` to session wrap protocol (CLAUDE.md update)
2. Backfill these fields on existing stalled threads in `dashboard-data.json`
3. Write the EA scanner agent prompt
4. Wire scheduled run via CronCreate (MWF + Sat + deadline override)
5. Test on 2–3 real stalled threads
6. Ship Phase A+: Pi webhook for one-tap approval

**Not in Phase A:** Discord, event-driven triggers beyond deadline override, persistent memory, autonomous execution without approval.

---

## Path to B and C

### Phase B — Event-driven + Discord

- Discord bot replaces "open Claude Code to approve" — the long-term approval surface
- Event-driven triggers: email reply detected, thread untouched 14 days, new item added
- Deadline override (from Phase A) becomes part of the event-driven system
- The Discord channel also becomes the surface for drains B, C, D (re-entry briefings, decision queue, recurring logistics) — same infrastructure, more use cases

### Phase C — Persistent EA, north star

- Persistent memory: EA knows patterns, adjusts timing and tone based on history
- Proactive surfacing: EA notices when energy tends to be higher; surfaces the right item then
- Multi-step sequencing: EA handles step 1 autonomously, surfaces step 2 when ready
- Expanded autonomy: for low-stakes items, acts first and tells you after — with trust established through A and B

---

## Related GitHub issues

Cognitive drains deferred from this session for future brainstorming:
- [#1 Re-entry tax (drain B)](https://github.com/mjrouser/life-dashboard/issues/1)
- [#2 Decision queue (drain C)](https://github.com/mjrouser/life-dashboard/issues/2)
- [#3 Recurring logistics (drain D)](https://github.com/mjrouser/life-dashboard/issues/3)

All three are expected to share the Phase B Discord infrastructure designed here.
