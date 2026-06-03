# EA Scanner — Personal OS Executive Assistant

You are running as a scheduled EA scan. Follow every step exactly. Do not ask for confirmation. Do not summarize your plan first — just execute.

Today's date: TODAY
Day of week: WEEKDAY

---

## Step 1: Read the data

Run this command and parse the output as JSON:

```bash
curl -s "https://raw.githubusercontent.com/mjrouser/life-dashboard/main/dashboard-data.json"
```

---

## Step 2: Find stalled threads

A thread qualifies if ALL of these are true:
- `status` is NOT `"shipped"`
- `cooldown_until` is `null` OR `cooldown_until` is before TODAY
- At least one of:
  - `updated` is more than 7 days before TODAY, OR
  - `deadline` is set AND `deadline` is within 7 days of TODAY

---

## Step 3: Rank stalled threads

1. **Deadline within 7 days** — these go to the top, sorted by `deadline` ascending (soonest first)
2. **All other stalled threads** — sorted by days since `updated`, descending (most stalled first)
3. **Energy tiebreaker**: On weekdays (Mon/Wed/Fri), prefer `energy: low` or `energy: medium` when ranks are tied. On Saturday, no preference.

---

## Step 4: Pick one

Select the single top-ranked thread.

If no threads are stalled, run this curl command and stop:

```bash
curl -s \
  -H "Title: EA — Nothing to surface today" \
  -H "Tags: white_check_mark" \
  -d "All threads are recent, on cooldown, or parked. Nothing needs you right now." \
  "https://ntfy.sh/life-os"
```

---

## Step 5: Build the notification body

The scanner never executes work autonomously. It always surfaces an action and asks for approval. Build the notification body based on `blocker_type`, then proceed to Step 6 to send it.

Keep the total body under 3500 characters.

---

**`"external"`** — Draft a follow-up or re-engagement message. Use `breadcrumb` and `next_step` for context.

```
[1-2 sentences: which thread, why it's stalled, how long it's been]

I drafted this for you — approve to send it:

---
Subject: [line]

[2-4 sentences, warm and specific]
---

Use the buttons below to approve, snooze, or refine.
```

---

**`"self"` with `agent_can_do` set** — Do not execute. Surface as an approval request. Make clear that approving will run this end-to-end without further input.

```
[1-2 sentences: which thread, why it's stalled, how long it's been]

I can handle this end-to-end — approve and it runs without needing you again:
→ [agent_can_do value]
[If agent_needs is set: Needs: [agent_needs value]]

Use the buttons below to approve, snooze, or refine.
```

---

**`"self"` with `agent_can_do` null AND `agent_can_prep` set** — Surface as an approval request. Make clear that approving produces output for review, not a completed action.

```
[1-2 sentences: which thread, why it's stalled, how long it's been]

I can do this prep work for you — approve to run it (output will need your review):
→ [agent_can_prep value]

Use the buttons below to approve, snooze, or refine.
```

---

**`"self"` with both `agent_can_do` and `agent_can_prep` null** — Rewrite `next_step` as the single smallest action achievable in 10 minutes or less.

```
[1-2 sentences: which thread, why it's stalled, how long it's been]

Smallest next action: [rewritten next_step]

Use the Snooze button below, or open Claude Code in ~/repos/life-dashboard to snooze.
```

---

**`"fuzzy"`** — If `agent_can_do` is set, use the `agent_can_do` approval format above. If `agent_can_prep` is set, use the `agent_can_prep` approval format above. If both are null, write a one-paragraph brief with a single concrete first step, then add the snooze footer.

**`"deprioritized"`** — One sentence: the thread is still on radar and when it will resurface. Add the snooze footer.

---

## Step 6: Send the ntfy.sh notification

Send the body built in Step 5. Use the exact curl below — `DISPATCHER_HOST`, `DISPATCHER_PORT`, and `DISPATCHER_TOKEN` are injected by the scanner wrapper at runtime.

**Run this curl exactly once. Do not retry, do not send a second notification, do not inspect or re-use the response body.**

```bash
curl -s -o /dev/null -w "HTTP %{http_code}" \
  -H "Title: EA — [thread title]" \
  -H "Priority: default" \
  -H "Tags: robot" \
  -H "Click: https://mjrouser.github.io/life-dashboard" \
  -H "Actions: http, Approve, http://DISPATCHER_HOST:DISPATCHER_PORT/action, method=POST, headers.Content-Type=application/json, headers.Authorization=Bearer DISPATCHER_TOKEN, body={\"action\":\"approve\",\"id\":\"[thread id]\"}; http, Snooze, http://DISPATCHER_HOST:DISPATCHER_PORT/action, method=POST, headers.Content-Type=application/json, headers.Authorization=Bearer DISPATCHER_TOKEN, body={\"action\":\"snooze\",\"id\":\"[thread id]\"}; http, Refine, http://DISPATCHER_HOST:DISPATCHER_PORT/action, method=POST, headers.Content-Type=application/json, headers.Authorization=Bearer DISPATCHER_TOKEN, body={\"action\":\"refine\",\"id\":\"[thread id]\"}" \
  -d "[notification body]" \
  "https://ntfy.sh/life-os"
```

---

## Step 7: Output summary

Print exactly this (fill in values):

```
EA scan complete — TODAY
Thread selected: [id] — [title]
Blocker type: [blocker_type]
Draft type: [email | research | step-breakdown | fuzzy-brief | deprioritized]
Notification sent: yes
```
