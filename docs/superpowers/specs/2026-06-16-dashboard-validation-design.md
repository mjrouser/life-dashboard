# Dashboard Data Validation Script — Design Spec

**Date:** 2026-06-16
**Status:** Approved

---

## Problem

`dashboard-data.json` is edited every session by Claude Code. There are no automated checks, so schema drift and invalid values (e.g. `status: "active"` — a value no section renders) can be committed silently and go unnoticed until a chat disappears from the dashboard.

---

## Solution

A standalone Node.js validation script with a pre-commit hook that blocks commits when `dashboard-data.json` is invalid.

---

## Architecture

Two files:

- **`scripts/validate-data.js`** — the validator
- **`.git/hooks/pre-commit`** — runs the validator on every commit (not committed to the repo)

The hook is not version-controlled. Installation is manual: one `cp` command documented in the script header.

---

## Script design (`scripts/validate-data.js`)

- No dependencies — stdlib only
- Reads `dashboard-data.json` from the repo root (resolved relative to the script location, so it works from any working directory)
- Six named check functions, called in sequence from `main()`
- Each function returns an array of error strings
- After all checks, errors are collected and printed
- Exits `0` if no errors, `1` if any errors found

**Output (clean):**
```
✓ dashboard-data.json is valid
```

**Output (errors):**
```
✗ dashboard-data.json has 2 error(s):

  [pe-career-transition] status "active" is not a valid value
  [today] chat_id "stale-id" does not reference a known chat
```

---

## Checks

| Check | What it validates |
|---|---|
| `checkStatuses()` | Each chat's `status` is one of: `active-deadline`, `active-in-progress`, `live-has-tail`, `ready`, `parked`, `queued`, `shipped` |
| `checkCategoryRefs()` | Each chat's `category_id` references a real entry in `categories[]` |
| `checkGroupRefs()` | Each chat's `group_id` (when present) references a real entry in `groups[]` |
| `checkTodayRefs()` | Each `today[].chat_id` references a real chat `id` |
| `checkEAFields()` | Each chat has all five EA fields present: `blocker_type`, `agent_can_do`, `agent_can_prep`, `agent_needs`, `cooldown_until` |
| `checkDateFormats()` | `updated` and `cooldown_until` (when non-null) match `YYYY-MM-DD` |

---

## Pre-commit hook (`.git/hooks/pre-commit`)

```sh
#!/bin/sh
node "$(git rev-parse --show-toplevel)/scripts/validate-data.js"
```

Exits non-zero if the validator fails, blocking the commit.

**Install command** (documented in script header):
```bash
printf '#!/bin/sh\nnode "$(git rev-parse --show-toplevel)/scripts/validate-data.js"\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

---

## What this does not cover

- JSON syntax errors (if the file isn't valid JSON, `JSON.parse` throws and the script exits with a clear message)
- Field type validation beyond date format (e.g. checking that `energy` is `low/medium/high`) — not worth the complexity now
- Cross-chat consistency (e.g. duplicate IDs) — can be added later if needed

---

## Files changed

| File | Action |
|---|---|
| `scripts/validate-data.js` | Create |
| `.git/hooks/pre-commit` | Create (manual install, not committed) |
