# Car Maintenance Schema — Design Spec
_2026-06-08_

## Problem

The dashboard is 2-level (category → thread). Car maintenance needs a 3rd grouping level — a sub-category under Household Admin — so tires, transmission fluid, and future maintenance items live together and agents have enough context to act on them without further input.

## Goals

- Sub-category grouping within Household Admin (and any future category)
- Vehicle facts in a structured, agent-readable registry
- Recurrence schema defined now so agent write-back has clear targets later
- Agent indicator visible on cards so it's obvious at a glance when a thread can be moved forward without direct involvement
- Rename `projects`/`project_id` → `categories`/`category_id` throughout — the current name has drifted from the actual concept

## Out of scope

- EA scanner recurrence surfacing logic (phase 2 — agent write-back spec)
- Recurrence UI on cards (no "due at X miles" display yet)
- Agent write-back mechanism (separate spec; triggered when first `last_done` update is needed)
- Sidebar, today strip, pickup card — no changes

---

## Schema Changes

### 1. Rename

| Before | After | Scope |
|---|---|---|
| `projects` top-level key | `categories` | `dashboard-data.json` |
| `project_id` on chat entries | `category_id` | every chat entry |
| `data.projects` in JS | `data.categories` | `index.html` |
| `c.project_id` in JS | `c.category_id` | `index.html` |
| `projectShort()` function | `categoryName()` | `index.html` |
| `activeFilter` state var | `activeCategory` | `index.html` |

### 2. New: `groups` registry

Top-level key, parallel to `categories`. Groups are scoped to a category.

```json
"groups": [
  {
    "id": "car",
    "name": "Car",
    "emoji": "🚗",
    "category_id": "household-admin",
    "vehicle_id": "primary"
  }
]
```

`vehicle_id` is optional — only groups that involve a vehicle carry it. Threads in the group inherit vehicle context by looking up their group's `vehicle_id` → `vehicles` registry. No `vehicle_id` on individual chat entries.

Chat entries get an optional `group_id` field. Absent = no sub-category. Fully backward compatible.

### 3. New: `vehicles` registry

Top-level key. Structured vehicle facts any agent can read from the JSON without cross-referencing threads.

```json
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
]
```

`mileage` + `mileage_updated` are the first write targets for the agent write-back phase.

### 4. New fields on chat entries

Three new optional fields. All absent = no behavior change for existing threads.

| Field | Type | Purpose |
|---|---|---|
| `group_id` | string or null | Sub-category within a category |
| `recurs_every` | object or null | `{ "miles": 50000 }` or `{ "months": 12 }` or both |
| `last_done` | object or null | `{ "date": "YYYY-MM-DD", "mileage": 47000 }` |

Vehicle context is inherited via `group_id` → `groups[id].vehicle_id` → `vehicles[id]`. No `vehicle_id` on individual threads.

`recurs_every` and `last_done` are schema-only in this phase. The EA scanner does not act on them yet.

### 5. First car threads

Two new chat entries under `household-admin` / `group_id: "car"`:

**`car-tires`**
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
  "energy": "medium",
  "blocker_type": "self",
  "agent_can_do": null,
  "agent_can_prep": "Research current tire options for [year/make/model/trim/tire_size], compare prices at Costco vs. local shops, and summarize top 3 recommendations",
  "agent_needs": "vehicle spec from vehicles registry",
  "cooldown_until": null,
  "updated": "2026-06-08"
}
```

**`car-transmission`**
```json
{
  "id": "car-transmission",
  "category_id": "household-admin",
  "group_id": "car",
  "title": "Car — Transmission Fluid",
  "status": "active-in-progress",
  "recurs_every": { "miles": 30000 },
  "last_done": null,
  "next_step": "TBD — populate after capturing vehicle spec sheet",
  "energy": "low",
  "blocker_type": "self",
  "agent_can_do": null,
  "agent_can_prep": "Look up transmission fluid service interval and fluid type for [year/make/model/trim], and find local shops or dealership options",
  "agent_needs": "vehicle spec from vehicles registry",
  "cooldown_until": null,
  "updated": "2026-06-08"
}
```

Both threads' `next_step` fields update once the vehicle spec sheet is captured (year/make/model/trim/tire size/mileage).

---

## UI Changes

### 1. Two filter rows

Row 1 (always visible) — category pills, same visual pattern as current project pills:
```
Filter  [All]  [🖥 Homelab]  [🏠 320 Sycamore]  ...  [📋 Household Admin]  |  [🧪 Tiny bets]
```

Row 2 (conditional) — appears below row 1 only when `activeCategory` has groups defined in `data.groups`:
```
Sub-cat  [All]  [🚗 Car]
```

State: `activeCategory` (replaces `activeFilter`) + `activeGroup` (new, default null). `activeGroup` resets to null when `activeCategory` changes. `tinyBetFilter` remains a global toggle in row 1.

Filtering logic: when both `activeCategory` and `activeGroup` are set, `filteredChats()` applies both (intersection). "All" in row 2 clears `activeGroup` without clearing `activeCategory`.

### 2. Group chip on cards

Renders in the card meta row when `group_id` is set:

```html
<span class="group-tag">🚗 Car</span>
```

Visual pattern mirrors `.bet-tag` — monospace, small, subtle background. Both chips can coexist on a card. Emoji and name sourced from `data.groups` lookup by `group_id`.

### 3. Agent indicator chip

Two distinct states, new color token separate from green accent and gold shipped:

- `agent_can_do` is set → solid chip: **`⚡ agent`** — "approve and it runs end-to-end, no further input needed"
- `agent_can_do` null + `agent_can_prep` set → muted/outlined chip: **`⚡ prep`** — "agent can do prep work; output needs your review"

Renders in the card meta row. The visual distinction (solid vs. outlined) matches the semantic distinction in the EA approval flow.

### 4. Sort by group within sections

When `activeCategory` is set and that category has groups in `data.groups`, cards within each status section sort:
1. Grouped threads first, clustered by `group_id` (alphabetical by group id)
2. Ungrouped threads last
3. Within each cluster, existing energy sort applies (low → medium → high)

No sub-headers for now — sorting alone provides visual grouping without DOM complexity.

---

## Post-implementation cleanup

After implementation, update `car-subcategory` thread (the meta-thread that tracked this design work):
- `last_completed`: "Design car maintenance schema — implement per spec"
- `next_step`: first implementation task
- `status`: `shipped` once implementation is done

---

## Phase 2 handoff condition

The natural trigger for the agent write-back spec: first time you or an agent needs to update `last_done` on a car thread after a service. At that point, open the write-back spec. The `vehicles.mileage` + `vehicles.mileage_updated` fields are also write targets from day one.
