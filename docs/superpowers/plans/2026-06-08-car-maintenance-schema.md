# Car Maintenance Schema Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add sub-category grouping (groups registry), vehicle registry, car maintenance threads, a group filter sub-row, group/agent chips on cards, and group-aware sort within status sections.

**Architecture:** Two-file edit: `dashboard-data.json` (data) and `index.html` (all JS + CSS). Changes are additive and backward-compatible — new fields on chat entries are optional and silently skipped by JS that doesn't know about them yet. The one exception: the rename (`projects`→`categories`) must touch both files in a single commit to avoid a broken intermediate state. All other tasks leave the app functional after each commit.

**Tech Stack:** Vanilla HTML/CSS/JS, no build step, no test framework. Validation: `python3 -m json.tool` for JSON; manual browser check via `python3 -m http.server 8080` for UI. Run the server from `~/repos/life-dashboard`.

---

### Task 1: Rename `projects`/`project_id` → `categories`/`category_id` across both files

**Files:**
- Modify: `dashboard-data.json`
- Modify: `index.html`

Both files change in one commit. After the rename, `index.html` reads `data.categories` — if only the JSON is renamed first, the dashboard breaks.

- [ ] **Step 1: Rename in `dashboard-data.json`**

Run from `~/repos/life-dashboard`:

```bash
python3 -c "
content = open('dashboard-data.json').read()
content = content.replace('\"projects\":', '\"categories\":', 1)
content = content.replace('\"project_id\":', '\"category_id\":')
open('dashboard-data.json', 'w').write(content)
print('JSON renamed')
"
```

- [ ] **Step 2: Validate JSON**

```bash
python3 -m json.tool dashboard-data.json > /dev/null && echo "JSON valid"
```

Expected output: `JSON valid`

- [ ] **Step 3: Rename in `index.html`**

```bash
python3 -c "
content = open('index.html').read()
content = content.replace('activeFilter', 'activeCategory')
content = content.replace('projectShort(', 'categoryName(')
content = content.replace('data.projects', 'data.categories')
content = content.replace('project_id', 'category_id')
open('index.html', 'w').write(content)
print('HTML renamed')
"
```

- [ ] **Step 4: Verify rename is complete in `index.html`**

Confirm new names are present:

```bash
grep -c "activeCategory\|categoryName\|data\.categories\|category_id" index.html
```

Expected: a number greater than 10.

Confirm old names are gone:

```bash
grep -c "activeFilter\|projectShort\|data\.projects\b\|project_id" index.html
```

Expected output: `0`

- [ ] **Step 5: Smoke test in browser**

```bash
python3 -m http.server 8080
```

Open `http://localhost:8080`. Verify:
- Dashboard loads with all cards visible
- Category filter pills work (click Homelab → only homelab cards show; click All → all cards show)
- Tiny bets toggle works

- [ ] **Step 6: Commit**

```bash
git add dashboard-data.json index.html
git commit -m "refactor: rename projects/project_id to categories/category_id"
```

---

### Task 2: Add `groups` and `vehicles` registries to `dashboard-data.json`

**Files:**
- Modify: `dashboard-data.json`

New top-level keys. The JS ignores them until Task 5 — purely additive.

- [ ] **Step 1: Insert `groups` and `vehicles` after the `categories` array**

Open `dashboard-data.json`. Find the end of the `categories` array — it ends with a `],` before `"today"`. Insert the following between that `],` and `"today"`:

```json
  "groups": [
    {
      "id": "car",
      "name": "Car",
      "emoji": "🚗",
      "category_id": "household-admin",
      "vehicle_id": "primary"
    }
  ],
  "vehicles": [
    {
      "id": "primary",
      "year": 2019,
      "make": "Toyota",
      "model": "Camry",
      "trim": "XSE",
      "tire_size": "235/45R18",
      "mileage": 47000,
      "mileage_updated": "2026-06-08"
    }
  ],
```

- [ ] **Step 2: Validate JSON**

```bash
python3 -m json.tool dashboard-data.json > /dev/null && echo "JSON valid"
```

Expected: `JSON valid`

- [ ] **Step 3: Verify top-level keys**

```bash
python3 -c "import json; d=json.load(open('dashboard-data.json')); print(list(d.keys()))"
```

Expected: `['meta', 'categories', 'groups', 'vehicles', 'today', 'chats', 'activity_log']`

- [ ] **Step 4: Commit**

```bash
git add dashboard-data.json
git commit -m "data: add groups and vehicles registries"
```

---

### Task 3: Add car maintenance threads to `dashboard-data.json`

**Files:**
- Modify: `dashboard-data.json`

Two new chat entries with `group_id`, `recurs_every`, and `last_done` fields. These fields are unknown to the JS at this point and are silently ignored — fully backward-compatible.

- [ ] **Step 1: Add `car-tires` and `car-transmission` after `car-subcategory` in the `chats` array**

Find the `car-subcategory` entry. Add both entries immediately after its closing `},`:

```json
    {
      "id": "car-tires",
      "category_id": "household-admin",
      "group_id": "car",
      "title": "Car — New Tires",
      "status": "active-in-progress",
      "recurs_every": { "miles": 50000 },
      "last_done": { "date": "2020-01-01", "mileage": 0 },
      "next_step": "TBD — populate after capturing vehicle spec sheet",
      "breadcrumb": null,
      "energy": "medium",
      "blocker_type": "self",
      "agent_can_do": null,
      "agent_can_prep": "Research current tire options for 2019 Toyota Camry XSE (235/45R18), compare prices at Costco vs. local shops, and summarize top 3 recommendations",
      "agent_needs": "current mileage from vehicles registry",
      "cooldown_until": null,
      "updated": "2026-06-08"
    },
    {
      "id": "car-transmission",
      "category_id": "household-admin",
      "group_id": "car",
      "title": "Car — Transmission Fluid",
      "status": "active-in-progress",
      "recurs_every": { "miles": 30000 },
      "last_done": null,
      "next_step": "TBD — populate after capturing vehicle spec sheet",
      "breadcrumb": null,
      "energy": "low",
      "blocker_type": "self",
      "agent_can_do": null,
      "agent_can_prep": "Look up transmission fluid service interval and fluid type for 2019 Toyota Camry XSE, and find local shops or dealership options in the Detroit area",
      "agent_needs": "current mileage from vehicles registry",
      "cooldown_until": null,
      "updated": "2026-06-08"
    },
```

Note: `agent_can_prep` uses real vehicle values from the `vehicles` registry (2019 Camry XSE, 235/45R18), not the `[placeholder]` form shown in the design spec.

- [ ] **Step 2: Validate JSON**

```bash
python3 -m json.tool dashboard-data.json > /dev/null && echo "JSON valid"
```

Expected: `JSON valid`

- [ ] **Step 3: Verify new entries**

```bash
python3 -c "
import json
d = json.load(open('dashboard-data.json'))
car = [c for c in d['chats'] if c['id'] in ('car-tires', 'car-transmission')]
for c in car: print(c['id'], c.get('group_id'), c.get('recurs_every'))
"
```

Expected:
```
car-tires car {'miles': 50000}
car-transmission car {'miles': 30000}
```

- [ ] **Step 4: Smoke test in browser**

Reload `http://localhost:8080`. Confirm both new threads appear in the `active-in-progress` section (under Household Admin). No group chip or agent chip yet — those come in Task 6.

- [ ] **Step 5: Commit**

```bash
git add dashboard-data.json
git commit -m "data: add car-tires and car-transmission threads"
```

---

### Task 4: Add CSS for group chip, agent indicator chips, and sub-filter row

**Files:**
- Modify: `index.html`

Pure CSS addition — no JS or behavior change. All existing styles are unchanged.

- [ ] **Step 1: Add `--agent-color` and `--agent-bg` to the light-mode `:root` block**

In `index.html`, find the `:root {` block (around line 10). Add two lines after `--today-border: #c5e0d3;`:

```css
    --agent-color: #2d6a9f;
    --agent-bg: #e8f0f8;
```

- [ ] **Step 2: Add dark-mode overrides for agent colors**

Find the `@media (prefers-color-scheme: dark) { :root {` block (around line 35). Add after `--today-border: #1d5040;`:

```css
      --agent-color: #60aee0;
      --agent-bg: #162535;
```

- [ ] **Step 3: Add chip and sub-filter CSS after the `.bet-tag` dark-mode block**

Find this exact closing brace (around line 160):

```css
  @media (prefers-color-scheme: dark) {
    .bet-tag {
      background: rgba(255,255,255,0.06);
      border-color: rgba(255,255,255,0.1);
    }
  }
```

Add the following immediately after it:

```css
  .group-tag {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--text-tertiary);
    background: rgba(0,0,0,0.04);
    border: 0.5px solid rgba(0,0,0,0.1);
    padding: 2px 7px;
    border-radius: 6px;
    flex-shrink: 0;
    white-space: nowrap;
  }
  @media (prefers-color-scheme: dark) {
    .group-tag {
      background: rgba(255,255,255,0.06);
      border-color: rgba(255,255,255,0.1);
    }
  }

  .agent-tag {
    font-family: var(--mono);
    font-size: 10px;
    color: #fff;
    background: var(--agent-color);
    border: 0.5px solid var(--agent-color);
    padding: 2px 7px;
    border-radius: 6px;
    flex-shrink: 0;
    white-space: nowrap;
  }
  @media (prefers-color-scheme: dark) {
    .agent-tag { color: #141413; }
  }

  .agent-prep-tag {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--agent-color);
    background: var(--agent-bg);
    border: 0.5px solid var(--agent-color);
    padding: 2px 7px;
    border-radius: 6px;
    flex-shrink: 0;
    white-space: nowrap;
    opacity: 0.85;
  }

  .subfilters {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    margin-bottom: 1.25rem;
    margin-top: -1rem;
    align-items: center;
  }
  .subfilter-label {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--text-tertiary);
    margin-right: 4px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
```

- [ ] **Step 4: Verify CSS addition (no visible change yet)**

Reload `http://localhost:8080`. Dashboard should look identical — the new CSS classes exist but nothing renders them yet.

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "style: add group-tag, agent-tag, agent-prep-tag, and subfilters CSS"
```

---

### Task 5: Add group filter sub-row and `activeGroup` state

**Files:**
- Modify: `index.html`

Wires up the second filter row and group filtering logic.

- [ ] **Step 1: Add `activeGroup` state variable**

Find (after Task 1 rename, around line 703):

```javascript
let activeCategory = null;
```

Add `activeGroup` on the next line:

```javascript
let activeCategory = null;
let activeGroup = null;
```

- [ ] **Step 2: Add `groupsForCategory()` helper**

Find the `categoryName(id)` function (around line 719). Add a new function immediately after its closing `}`:

```javascript
function groupsForCategory(categoryId) {
  if (!data.groups) return [];
  return data.groups.filter(g => g.category_id === categoryId);
}
```

- [ ] **Step 3: Update `filteredChats()` to apply `activeGroup`**

Find `filteredChats()`. Replace the entire function:

```javascript
function filteredChats() {
  let chats = data.chats;
  if (activeCategory) chats = chats.filter(c => c.category_id === activeCategory);
  if (activeGroup) chats = chats.filter(c => c.group_id === activeGroup);
  if (tinyBetFilter) chats = chats.filter(c => c.tiny_bet === true);
  return chats;
}
```

- [ ] **Step 4: Update `setFilter()` to reset `activeGroup` on category change**

Find `setFilter(id)`. Replace the entire function:

```javascript
function setFilter(id) {
  activeCategory = activeCategory === id ? null : id;
  activeGroup = null;
  render();
}
```

- [ ] **Step 5: Add `setGroupFilter()` function**

Add immediately after `setFilter()`:

```javascript
function setGroupFilter(id) {
  activeGroup = id;
  render();
}
```

- [ ] **Step 6: Add group sub-row to filter pill rendering**

Find the filter pills block in `render()`. It ends with:

```javascript
  html += '</div>';

  // Energy legend
```

Insert the sub-row block between that `html += '</div>';` and the `// Energy legend` comment:

```javascript
  // Group sub-row — appears only when active category has groups
  if (activeCategory) {
    const groups = groupsForCategory(activeCategory);
    if (groups.length > 0) {
      html += '<div class="subfilters"><span class="subfilter-label">Sub-cat</span>';
      html += `<button class="pill ${!activeGroup ? 'active' : ''}" onclick="setGroupFilter(null)">All</button>`;
      groups.forEach(g => {
        html += `<button class="pill ${activeGroup === g.id ? 'active' : ''}" onclick="setGroupFilter('${g.id}')">${g.emoji} ${g.name}</button>`;
      });
      html += '</div>';
    }
  }
```

- [ ] **Step 7: Verify group filter in browser**

Reload `http://localhost:8080`.

- Click `📋 Household Admin`. A second filter row should appear: `Sub-cat  [All]  [🚗 Car]`
- Click `🚗 Car`. Only `car-tires` and `car-transmission` should show.
- Click `All` in the sub-row. All Household Admin threads show.
- Click `🖥 Homelab` (or any other category). Sub-row disappears (Homelab has no groups).
- Click `All` in row 1. Sub-row disappears, all threads show.

- [ ] **Step 8: Commit**

```bash
git add index.html
git commit -m "feat: add group filter sub-row and activeGroup state"
```

---

### Task 6: Add group chip and agent indicator chip to cards

**Files:**
- Modify: `index.html`

Both chips render in the `.card-meta` row, after the existing `tiny-bet` chip.

- [ ] **Step 1: Add chips after the `tiny_bet` chip in the card meta row**

Find in `render()` (inside the `SECTIONS.forEach` loop):

```javascript
      if (c.tiny_bet) html += `<span class="bet-tag">🧪 tiny bet</span>`;
      html += '</div>';
```

Insert the new chips between those two lines:

```javascript
      if (c.tiny_bet) html += `<span class="bet-tag">🧪 tiny bet</span>`;
      if (c.group_id && data.groups) {
        const g = data.groups.find(grp => grp.id === c.group_id);
        if (g) html += `<span class="group-tag">${esc(g.emoji)} ${esc(g.name)}</span>`;
      }
      if (c.agent_can_do) {
        html += `<span class="agent-tag">⚡ agent</span>`;
      } else if (c.agent_can_prep) {
        html += `<span class="agent-prep-tag">⚡ prep</span>`;
      }
      html += '</div>';
```

- [ ] **Step 2: Verify chips in browser**

Reload `http://localhost:8080`.

- `car-tires` and `car-transmission` cards each show a `🚗 Car` chip and a `⚡ prep` chip (outlined/muted — they have `agent_can_prep` set, `agent_can_do: null`).
- Other cards with `agent_can_prep` (e.g. `renovations`, `pihole-ipv6`) also show `⚡ prep`.
- Cards with neither field show no agent chip.
- To verify the solid `⚡ agent` style: temporarily set `"agent_can_do": "test"` on any thread in the JSON, reload, confirm the chip is solid/filled blue, then revert the JSON change.

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: add group chip and agent indicator chip to cards"
```

---

### Task 7: Add group-aware sort within status sections

**Files:**
- Modify: `index.html`

When a category with groups is active, cards within each section sort: grouped threads first (clustered by registry order of `group_id`), ungrouped threads last, energy sort within each cluster. When no category is active, behavior is unchanged (energy sort only).

- [ ] **Step 1: Add `sortChatsForSection()` helper**

Add this function immediately after `groupsForCategory()` (added in Task 5):

```javascript
function sortChatsForSection(chats) {
  if (!activeCategory) {
    return [...chats].sort((a, b) =>
      (ENERGY_ORDER[a.energy] ?? 1) - (ENERGY_ORDER[b.energy] ?? 1)
    );
  }
  const groups = groupsForCategory(activeCategory);
  if (groups.length === 0) {
    return [...chats].sort((a, b) =>
      (ENERGY_ORDER[a.energy] ?? 1) - (ENERGY_ORDER[b.energy] ?? 1)
    );
  }
  const groupOrder = {};
  groups.forEach((g, i) => { groupOrder[g.id] = i; });

  return [...chats].sort((a, b) => {
    const aGrouped = a.group_id != null;
    const bGrouped = b.group_id != null;
    if (aGrouped !== bGrouped) return aGrouped ? -1 : 1;
    if (aGrouped && bGrouped) {
      const aOrd = groupOrder[a.group_id] ?? 999;
      const bOrd = groupOrder[b.group_id] ?? 999;
      if (aOrd !== bOrd) return aOrd - bOrd;
    }
    return (ENERGY_ORDER[a.energy] ?? 1) - (ENERGY_ORDER[b.energy] ?? 1);
  });
}
```

- [ ] **Step 2: Use `sortChatsForSection()` in `SECTIONS.forEach`**

Find in `render()`:

```javascript
  SECTIONS.forEach(sec => {
    const items = chats.filter(c => c.status === sec.key);
```

Replace with:

```javascript
  SECTIONS.forEach(sec => {
    const items = sortChatsForSection(chats.filter(c => c.status === sec.key));
```

- [ ] **Step 3: Verify sort in browser**

Click `📋 Household Admin`. In the active-in-progress section:
- `car-transmission` (energy: low) and `car-tires` (energy: medium) appear first, clustered together
- `car-subcategory`, `cellular-switch` (no `group_id`) appear after
- Within the car cluster, `car-transmission` (low energy) appears before `car-tires` (medium energy)

Click `All` to deselect. Confirm other categories show no reordering change (sort is energy-only when no category is active).

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: sort grouped threads first within sections when category filter is active"
```

---

### Task 8: Update `car-subcategory` meta-thread (post-implementation cleanup)

**Files:**
- Modify: `dashboard-data.json`

Per the spec: mark this design-tracking thread as shipped now that implementation is complete.

- [ ] **Step 1: Update `car-subcategory` fields**

Find the `car-subcategory` entry in `dashboard-data.json`. Replace these fields:

```json
      "status": "shipped",
      "last_completed": "Design and implement car maintenance schema — groups registry, vehicles registry, car threads, group filter row, group/agent chips, group sort",
      "next_step": null,
      "energy": null,
      "breadcrumb": "Schema design spec at docs/superpowers/specs/2026-06-08-car-maintenance-schema-design.md. Implementation complete.",
      "updated": "2026-06-08",
      "shipped_count": 1,
      "celebrated": false
```

Remove `open_question` or set it to `null`.

- [ ] **Step 2: Validate JSON**

```bash
python3 -m json.tool dashboard-data.json > /dev/null && echo "JSON valid"
```

Expected: `JSON valid`

- [ ] **Step 3: Verify in browser**

Reload `http://localhost:8080`. `car-subcategory` should appear in the Shipped sidebar. The two car threads remain in active-in-progress under Household Admin.

- [ ] **Step 4: Commit and push**

```bash
git add dashboard-data.json
git commit -m "data: mark car-subcategory as shipped — implementation complete"
git push
```

- [ ] **Step 5: Verify on live site**

Open `https://mjrouser.github.io/life-dashboard` (may take ~30s to deploy). Confirm:
- `📋 Household Admin` filter shows the group sub-row
- Car threads show `🚗 Car` and `⚡ prep` chips
- `car-subcategory` is in the Shipped sidebar
