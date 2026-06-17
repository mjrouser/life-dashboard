# Dashboard Validation Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Node.js validation script for `dashboard-data.json` that runs as a pre-commit hook, catching schema and referential integrity errors before they reach the repo.

**Architecture:** A single standalone script (`scripts/validate-data.js`) with six named check functions. Tests run the script against fixture files — one valid, one with a known error for each check type. The pre-commit hook is a two-line shell script installed manually into `.git/hooks/`.

**Tech Stack:** Node.js stdlib only (no npm, no dependencies). Shell for the hook.

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `scripts/validate-data.js` | Create | The validator — all six checks, entry point |
| `scripts/fixtures/valid-data.json` | Create | Minimal valid data used to confirm clean exit |
| `scripts/fixtures/invalid-data.json` | Create | One error of each type — verifies all checks fire |
| `.git/hooks/pre-commit` | Create (manual, not committed) | Runs validator on every commit |

---

## Task 1: Create test fixtures

**Files:**
- Create: `scripts/fixtures/valid-data.json`
- Create: `scripts/fixtures/invalid-data.json`

- [ ] **Step 1: Create `scripts/fixtures/valid-data.json`**

```json
{
  "meta": { "last_updated": "2026-06-16T00:00:00Z", "version": "1.0" },
  "categories": [
    { "id": "test-category", "name": "Test", "emoji": "🧪" }
  ],
  "groups": [
    { "id": "test-group", "name": "Test Group", "emoji": "🔧", "category_id": "test-category" }
  ],
  "today": [
    { "chat_id": "good-chat" }
  ],
  "chats": [
    {
      "id": "good-chat",
      "category_id": "test-category",
      "title": "Good Chat",
      "status": "active-in-progress",
      "next_step": "do something",
      "breadcrumb": "context",
      "energy": "low",
      "updated": "2026-06-16",
      "blocker_type": null,
      "agent_can_do": null,
      "agent_can_prep": null,
      "agent_needs": null,
      "cooldown_until": null
    }
  ],
  "activity_log": []
}
```

- [ ] **Step 2: Create `scripts/fixtures/invalid-data.json`**

This file has one error of each check type. Expected total: 11 errors (1 status, 1 category ref, 1 group ref, 1 today ref, 5 missing EA fields, 2 bad dates).

```json
{
  "meta": { "last_updated": "2026-06-16T00:00:00Z", "version": "1.0" },
  "categories": [
    { "id": "test-category", "name": "Test", "emoji": "🧪" }
  ],
  "groups": [
    { "id": "test-group", "name": "Test Group", "emoji": "🔧", "category_id": "test-category" }
  ],
  "today": [
    { "chat_id": "good-chat" },
    { "chat_id": "stale-ref" }
  ],
  "chats": [
    {
      "id": "good-chat",
      "category_id": "test-category",
      "title": "Good Chat",
      "status": "active-in-progress",
      "next_step": "do something",
      "breadcrumb": "context",
      "energy": "low",
      "updated": "2026-06-16",
      "blocker_type": null,
      "agent_can_do": null,
      "agent_can_prep": null,
      "agent_needs": null,
      "cooldown_until": null
    },
    {
      "id": "bad-status-chat",
      "category_id": "test-category",
      "title": "Bad Status",
      "status": "active",
      "next_step": "do something",
      "breadcrumb": "context",
      "energy": "low",
      "updated": "2026-06-16",
      "blocker_type": null,
      "agent_can_do": null,
      "agent_can_prep": null,
      "agent_needs": null,
      "cooldown_until": null
    },
    {
      "id": "bad-category-chat",
      "category_id": "nonexistent-category",
      "title": "Bad Category",
      "status": "active-in-progress",
      "next_step": "do something",
      "breadcrumb": "context",
      "energy": "low",
      "updated": "2026-06-16",
      "blocker_type": null,
      "agent_can_do": null,
      "agent_can_prep": null,
      "agent_needs": null,
      "cooldown_until": null
    },
    {
      "id": "bad-group-chat",
      "category_id": "test-category",
      "group_id": "nonexistent-group",
      "title": "Bad Group",
      "status": "active-in-progress",
      "next_step": "do something",
      "breadcrumb": "context",
      "energy": "low",
      "updated": "2026-06-16",
      "blocker_type": null,
      "agent_can_do": null,
      "agent_can_prep": null,
      "agent_needs": null,
      "cooldown_until": null
    },
    {
      "id": "missing-ea-chat",
      "category_id": "test-category",
      "title": "Missing EA Fields",
      "status": "active-in-progress",
      "next_step": "do something",
      "breadcrumb": "context",
      "energy": "low",
      "updated": "2026-06-16"
    },
    {
      "id": "bad-date-chat",
      "category_id": "test-category",
      "title": "Bad Dates",
      "status": "active-in-progress",
      "next_step": "do something",
      "breadcrumb": "context",
      "energy": "low",
      "updated": "06/16/2026",
      "blocker_type": null,
      "agent_can_do": null,
      "agent_can_prep": null,
      "agent_needs": null,
      "cooldown_until": "not-a-date"
    }
  ],
  "activity_log": []
}
```

- [ ] **Step 3: Commit fixtures**

```bash
git add scripts/fixtures/
git commit -m "test: add validation fixtures (valid + invalid)"
```

---

## Task 2: Create the validator script

**Files:**
- Create: `scripts/validate-data.js`

- [ ] **Step 1: Create `scripts/validate-data.js`**

```javascript
#!/usr/bin/env node
// validate-data.js — validates dashboard-data.json schema and referential integrity
// Usage: node scripts/validate-data.js [path/to/dashboard-data.json]
// Install pre-commit hook:
//   printf '#!/bin/sh\nnode "$(git rev-parse --show-toplevel)/scripts/validate-data.js"\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

const fs = require('fs');
const path = require('path');

const DATA_PATH = process.argv[2] || path.join(__dirname, '..', 'dashboard-data.json');

const VALID_STATUSES = new Set([
  'active-deadline', 'active-in-progress', 'live-has-tail',
  'ready', 'parked', 'queued', 'shipped'
]);

const EA_FIELDS = ['blocker_type', 'agent_can_do', 'agent_can_prep', 'agent_needs', 'cooldown_until'];
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

function checkStatuses(data) {
  const errors = [];
  for (const chat of data.chats) {
    if (!VALID_STATUSES.has(chat.status)) {
      errors.push(`[${chat.id}] status "${chat.status}" is not a valid value`);
    }
  }
  return errors;
}

function checkCategoryRefs(data) {
  const errors = [];
  const categoryIds = new Set(data.categories.map(c => c.id));
  for (const chat of data.chats) {
    if (!categoryIds.has(chat.category_id)) {
      errors.push(`[${chat.id}] category_id "${chat.category_id}" does not reference a known category`);
    }
  }
  return errors;
}

function checkGroupRefs(data) {
  const errors = [];
  const groupIds = new Set((data.groups || []).map(g => g.id));
  for (const chat of data.chats) {
    if (chat.group_id && !groupIds.has(chat.group_id)) {
      errors.push(`[${chat.id}] group_id "${chat.group_id}" does not reference a known group`);
    }
  }
  return errors;
}

function checkTodayRefs(data) {
  const errors = [];
  const chatIds = new Set(data.chats.map(c => c.id));
  for (const entry of (data.today || [])) {
    if (!chatIds.has(entry.chat_id)) {
      errors.push(`[today] chat_id "${entry.chat_id}" does not reference a known chat`);
    }
  }
  return errors;
}

function checkEAFields(data) {
  const errors = [];
  for (const chat of data.chats) {
    for (const field of EA_FIELDS) {
      if (!(field in chat)) {
        errors.push(`[${chat.id}] missing required EA field: ${field}`);
      }
    }
  }
  return errors;
}

function checkDateFormats(data) {
  const errors = [];
  for (const chat of data.chats) {
    if (chat.updated && !DATE_RE.test(chat.updated)) {
      errors.push(`[${chat.id}] updated "${chat.updated}" is not a valid YYYY-MM-DD date`);
    }
    if (chat.cooldown_until && !DATE_RE.test(chat.cooldown_until)) {
      errors.push(`[${chat.id}] cooldown_until "${chat.cooldown_until}" is not a valid YYYY-MM-DD date`);
    }
  }
  return errors;
}

function main() {
  let data;
  try {
    data = JSON.parse(fs.readFileSync(DATA_PATH, 'utf8'));
  } catch (e) {
    console.error(`✗ Could not read or parse ${DATA_PATH}: ${e.message}`);
    process.exit(1);
  }

  const errors = [
    ...checkStatuses(data),
    ...checkCategoryRefs(data),
    ...checkGroupRefs(data),
    ...checkTodayRefs(data),
    ...checkEAFields(data),
    ...checkDateFormats(data),
  ];

  if (errors.length === 0) {
    console.log('✓ dashboard-data.json is valid');
    process.exit(0);
  } else {
    console.error(`✗ dashboard-data.json has ${errors.length} error(s):\n`);
    for (const err of errors) {
      console.error(`  ${err}`);
    }
    process.exit(1);
  }
}

main();
```

- [ ] **Step 2: Run against the invalid fixture — expect 11 errors**

```bash
node scripts/validate-data.js scripts/fixtures/invalid-data.json
```

Expected output:
```
✗ dashboard-data.json has 11 error(s):

  [bad-status-chat] status "active" is not a valid value
  [bad-category-chat] category_id "nonexistent-category" does not reference a known category
  [bad-group-chat] group_id "nonexistent-group" does not reference a known group
  [today] chat_id "stale-ref" does not reference a known chat
  [missing-ea-chat] missing required EA field: blocker_type
  [missing-ea-chat] missing required EA field: agent_can_do
  [missing-ea-chat] missing required EA field: agent_can_prep
  [missing-ea-chat] missing required EA field: agent_needs
  [missing-ea-chat] missing required EA field: cooldown_until
  [bad-date-chat] updated "06/16/2026" is not a valid YYYY-MM-DD date
  [bad-date-chat] cooldown_until "not-a-date" is not a valid YYYY-MM-DD date
```

If the count or messages differ, fix the script before continuing.

- [ ] **Step 3: Run against the valid fixture — expect clean exit**

```bash
node scripts/validate-data.js scripts/fixtures/valid-data.json
echo "Exit code: $?"
```

Expected output:
```
✓ dashboard-data.json is valid
Exit code: 0
```

- [ ] **Step 4: Run against the real dashboard-data.json — expect clean exit**

```bash
node scripts/validate-data.js
echo "Exit code: $?"
```

Expected output:
```
✓ dashboard-data.json is valid
Exit code: 0
```

If it reports errors, fix `dashboard-data.json` before continuing.

- [ ] **Step 5: Commit the script**

```bash
git add scripts/validate-data.js
git commit -m "feat: add dashboard-data.json validation script"
```

---

## Task 3: Install the pre-commit hook

**Files:**
- Create: `.git/hooks/pre-commit` (manual install, not committed)

- [ ] **Step 1: Install the hook**

```bash
printf '#!/bin/sh\nnode "$(git rev-parse --show-toplevel)/scripts/validate-data.js"\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

- [ ] **Step 2: Verify the hook is executable**

```bash
ls -la .git/hooks/pre-commit
```

Expected: `-rwxr-xr-x` permissions on the file.

- [ ] **Step 3: Smoke test the hook — valid state**

Make an empty commit to trigger the hook without changing any files.

```bash
git commit --allow-empty -m "test: verify pre-commit hook fires cleanly"
```

Expected: commit succeeds, no validation errors printed.

- [ ] **Step 4: Smoke test the hook — blocked state**

Temporarily break `dashboard-data.json`, stage it, and confirm the commit is blocked.

```bash
# Inject a bad status
node -e "
const fs = require('fs');
const d = JSON.parse(fs.readFileSync('dashboard-data.json', 'utf8'));
d.chats[0].status = 'active';
fs.writeFileSync('dashboard-data.json', JSON.stringify(d, null, 2));
"
git add dashboard-data.json
git commit -m "should be blocked"
```

Expected: commit fails with:
```
✗ dashboard-data.json has 1 error(s):

  [<first-chat-id>] status "active" is not a valid value
```

- [ ] **Step 5: Restore `dashboard-data.json`**

```bash
git checkout dashboard-data.json
```

- [ ] **Step 6: Push the script and fixtures**

```bash
git push
```
