# Completion Loops Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add celebratory card treatment for completed steps and a "done today" summary inside the Pick Up Here card, both driven by a new optional `last_completed` field on chat entries.

**Architecture:** Pure front-end feature — no backend, no write-back from browser. CSS handles sparkle animation and pill styling; JS card render loop conditionally prepends a completed row when `last_completed` is set; the Pick Up Here block appends a done-today list when any chats have `last_completed` AND `updated === today`. The `last_completed` field is set by Claude Code during session wrap (not by the browser).

**Tech Stack:** Vanilla HTML/CSS/JS; single `index.html` + `dashboard-data.json`; local dev via `python3 -m http.server 8080`.

---

### Task 1: CSS — sparkle animation, done pill, completed row

**Files:**
- Modify: `index.html` — CSS block, after line 389 (after the existing `prefers-reduced-motion` block for ship animations)

- [ ] **Step 1: Locate insertion point**

Open `index.html`. Find the block ending at line 389:
```css
  @media (prefers-reduced-motion: no-preference) {
    .ship-celebrate { animation: ship-in 0.4s ease-out both; }
    .ship-celebrate .shipped-badge { animation: trophy-bounce 0.5s ease-in-out 0.4s both; }
  }
```
Insert the new CSS block immediately after the closing `}` of this media query (before the `/* ── Win of the Day ── */` comment on line 391).

- [ ] **Step 2: Insert completion loop CSS**

Add the following block at that insertion point:

```css
  /* ── Completion loops — card treatment ── */
  @keyframes sparkle-rise {
    from { opacity: 0; transform: translateY(4px); }
    to   { opacity: 1; transform: translateY(0); }
  }

  .sparkle-wrap {
    position: relative;
    display: inline-block;
    flex-shrink: 0;
    margin-top: 2px;
  }

  .sparkle-above {
    position: absolute;
    top: -17px; left: -2px;
    width: 68px; height: 18px;
    pointer-events: none;
  }

  .sparkle-above span { position: absolute; font-style: normal; }

  @media (prefers-reduced-motion: no-preference) {
    .sparkle-above span { animation: sparkle-rise 0.5s ease-out both; }
  }

  .done-pill {
    font-family: var(--mono);
    font-size: 10px;
    font-weight: 600;
    padding: 2px 7px;
    border-radius: 4px;
    white-space: nowrap;
    display: inline-flex;
    align-items: center;
    gap: 4px;
    background: linear-gradient(135deg, #e8f4ef 0%, #d4edde 100%);
    color: var(--accent);
    border: 1px solid rgba(29,107,84,0.3);
    box-shadow: 0 1px 3px rgba(29,107,84,0.15);
  }

  @media (prefers-color-scheme: dark) {
    .done-pill {
      background: linear-gradient(135deg, #0f2e23 0%, #122a20 100%);
      border-color: rgba(93,202,165,0.3);
      box-shadow: 0 1px 3px rgba(93,202,165,0.1);
    }
  }

  .completed-row {
    display: flex;
    align-items: flex-start;
    gap: 8px;
    margin-bottom: 6px;
    padding-top: 18px; /* room for sparkles above */
  }

  .completed-step-text {
    color: var(--text-secondary);
    font-size: 13px;
    line-height: 1.4;
  }

  .done-divider {
    border: none;
    border-top: 0.5px solid var(--border);
    margin: 6px 0 8px;
  }
```

- [ ] **Step 3: Visual smoke test (no JS yet)**

Start local server if not running:
```bash
cd ~/repos/life-dashboard && python3 -m http.server 8080
```
Open http://localhost:8080 — page should load normally with no visual change (no `last_completed` data yet). Check browser console for CSS errors — expect none.

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: add sparkle animation, done pill, and completed row CSS"
```

---

### Task 2: CSS — done-today section in Pick Up Here

**Files:**
- Modify: `index.html` — CSS block, after the block added in Task 1

- [ ] **Step 1: Locate insertion point**

Immediately after the `.done-divider` rule added in Task 1, add the following block:

- [ ] **Step 2: Insert done-today CSS**

```css
  /* ── Completion loops — done today (Pick Up Here) ── */
  .pickup-done-divider {
    border: none;
    border-top: 0.5px solid var(--border);
    margin: 8px 0 6px;
  }

  .pickup-done-label {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--text-tertiary);
    margin-bottom: 5px;
  }

  .pickup-done-win {
    font-size: 13px;
    line-height: 1.4;
    margin-bottom: 3px;
  }

  .pickup-done-title { color: var(--accent); font-weight: 300; }
  .pickup-done-step  { color: var(--text-secondary); }
```

No dark mode overrides needed here — all values use CSS variables that already adapt.

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: add done-today CSS for Pick Up Here section"
```

---

### Task 3: JS — card render: completed row when `last_completed` is set

**Files:**
- Modify: `index.html` — `render()` function, card render loop (~line 916)

- [ ] **Step 1: Locate the insertion point**

In `render()`, find the card render loop. The relevant lines look like:
```js
      html += `<div class="card-top">
        <span class="card-title">${esc(c.title)}</span>
        <span class="card-project">${projectShort(c.project_id)}</span>
      </div>`;
      if (c.next_step) html += `<div class="card-next"><strong>Next:</strong> ${esc(c.next_step)}</div>`;
```

The new block goes between the closing `</div>` of `.card-top` and the existing `if (c.next_step)` line.

- [ ] **Step 2: Insert completed row JS**

Replace this exact block:
```js
      if (c.next_step) html += `<div class="card-next"><strong>Next:</strong> ${esc(c.next_step)}</div>`;
```

With:
```js
      if (c.last_completed) {
        html += '<div class="completed-row">';
        html += '<div class="sparkle-wrap">';
        html += '<em class="sparkle-above" aria-hidden="true">';
        html += '<span style="left:0px;top:4px;font-size:9px;color:var(--shipped-gold);opacity:0.7;animation-delay:0s">✦</span>';
        html += '<span style="left:12px;top:0px;font-size:13px;color:var(--shipped-gold);opacity:1.0;animation-delay:0.08s">✦</span>';
        html += '<span style="left:27px;top:5px;font-size:8px;color:var(--accent);opacity:0.55;animation-delay:0.14s">✦</span>';
        html += '<span style="left:37px;top:-1px;font-size:12px;color:var(--accent);opacity:0.8;animation-delay:0.06s">✦</span>';
        html += '<span style="left:52px;top:3px;font-size:9px;color:var(--shipped-gold);opacity:0.6;animation-delay:0.18s">✦</span>';
        html += '</em>';
        html += '<span class="done-pill">✓ done</span>';
        html += '</div>';
        html += `<span class="completed-step-text">${esc(c.last_completed)}</span>`;
        html += '</div>';
        html += '<hr class="done-divider">';
      }
      if (c.next_step) html += `<div class="card-next"><strong>Next:</strong> ${esc(c.next_step)}</div>`;
```

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: render completed row with sparkles and done pill on cards"
```

---

### Task 4: JS — Pick Up Here: done-today section

**Files:**
- Modify: `index.html` — `render()` function, Pick Up Here block (~line 891)

- [ ] **Step 1: Locate the insertion point**

In `render()`, find the Pick Up Here block. It ends with:
```js
    if (mostRecent.open_question) {
      html += `<div class="pickup-question"><strong>Open question:</strong> ${esc(mostRecent.open_question)}</div>`;
    }
    html += '</div>';
```

The new block goes between the `open_question` block and the final `html += '</div>';`.

- [ ] **Step 2: Insert done-today JS**

Replace this exact block:
```js
    if (mostRecent.open_question) {
      html += `<div class="pickup-question"><strong>Open question:</strong> ${esc(mostRecent.open_question)}</div>`;
    }
    html += '</div>';
```

With:
```js
    if (mostRecent.open_question) {
      html += `<div class="pickup-question"><strong>Open question:</strong> ${esc(mostRecent.open_question)}</div>`;
    }
    const todayStr = new Date().toISOString().slice(0, 10);
    const wins = data.chats.filter(c => c.last_completed && c.updated === todayStr);
    if (wins.length > 0) {
      html += '<hr class="pickup-done-divider">';
      html += '<div class="pickup-done-label">✦ done today</div>';
      wins.forEach(w => {
        html += '<div class="pickup-done-win">';
        html += `<span class="pickup-done-title">${esc(w.title)}</span>`;
        html += ` — <span class="pickup-done-step">${esc(w.last_completed)}</span>`;
        html += '</div>';
      });
    }
    html += '</div>';
```

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: add done-today wins list to Pick Up Here card"
```

---

### Task 5: Add test data and verify in browser

**Files:**
- Modify: `dashboard-data.json` — one existing chat entry

- [ ] **Step 1: Pick a test card**

Open `dashboard-data.json`. Find the first chat entry that has both a `next_step` and a non-shipped status. A good candidate is any `active-in-progress` card. Note its current `next_step` value — that becomes `last_completed`.

- [ ] **Step 2: Add test fields**

On that chat entry, add two fields:
- `"last_completed": "<the current next_step value>"`
- Set `"updated": "2026-05-19"` (today — so it appears in "done today")

Example — if the entry currently looks like:
```json
{
  "id": "pihole-ipv6",
  "title": "PiHole",
  "status": "active-in-progress",
  "next_step": "Configure IPv6 virtual IP on keepalived",
  "updated": "2026-05-18",
  ...
}
```

Update it to:
```json
{
  "id": "pihole-ipv6",
  "title": "PiHole",
  "status": "active-in-progress",
  "last_completed": "Configure IPv4 failover with keepalived",
  "next_step": "Configure IPv6 virtual IP on keepalived",
  "updated": "2026-05-19",
  ...
}
```

- [ ] **Step 3: Verify card treatment in browser**

Reload http://localhost:8080. On the test card, verify:
- Completed row appears above the next step with sparkle glyphs visible above the pill
- "✓ done" green gradient pill is present
- Muted step text shows the `last_completed` value
- Hairline divider separates the completed row from the next step row
- Cards WITHOUT `last_completed` are unchanged
- Sparkles animate in on load (if `prefers-reduced-motion` is not set)

Toggle dark mode via browser DevTools → Rendering → "Emulate CSS media feature prefers-color-scheme: dark". Verify pill uses dark gradient.

- [ ] **Step 4: Verify done-today in Pick Up Here**

If the test card's `updated` is today, confirm the Pick Up Here card shows a "✦ done today" section at the bottom listing the card title and completed step. If the test card isn't the most-recent chat, update a second card with today's date and `last_completed` to test independently — the Pick Up Here wins list queries `data.chats` directly, not just the most-recent card.

- [ ] **Step 5: Remove test data (or keep if it's accurate)**

If the `last_completed` value added is not a real completed step, remove it and revert `updated` to the original date. If it represents real work done, keep it.

- [ ] **Step 6: Commit**

```bash
git add dashboard-data.json
git commit -m "test: add last_completed to verify completion loops rendering"
```

(Or if reverting: `git add dashboard-data.json && git commit -m "revert: remove test last_completed data"`)

---

### Task 6: Update CLAUDE.md session wrap protocol

**Files:**
- Modify: `CLAUDE.md` — session wrap protocol section

- [ ] **Step 1: Locate the session wrap protocol section**

Open `CLAUDE.md`. Find the section titled `## Session wrap protocol`. Within it, find the **Dashboard update** paragraph that begins:

> **Dashboard update:** After wrapping, update `dashboard-data.json` for the relevant chat entry:

- [ ] **Step 2: Add last_completed instruction**

Add `last_completed` to the bullet list of fields to set. Insert this line immediately after the `next_step` bullet:

Before:
```
- Set `next_step`, `breadcrumb`, `energy`, `updated` (today's date YYYY-MM-DD)
```

After:
```
- Set `next_step`, `breadcrumb`, `energy`, `updated` (today's date YYYY-MM-DD)
- When updating `next_step`, also set `last_completed` to the **previous** `next_step` value (the step just completed). Omit `last_completed` if `next_step` is unchanged.
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add last_completed to session wrap protocol"
```

---

### Task 7: Push and close

- [ ] **Step 1: Push to GitHub Pages**

```bash
git push
```

Expected: fast-forward push to `main`, GitHub Pages redeploys automatically.

- [ ] **Step 2: Verify on live site**

Open the GitHub Pages URL. Confirm the page loads, cards without `last_completed` look normal, and (if any test data was kept) the completion row renders correctly.

- [ ] **Step 3: File issue if any edge cases surfaced during testing**

```bash
gh issue create --title "Completion loops: <edge case>" --label "P2-nice-to-have" --body "<description>"
```

---

## Self-review

**Spec coverage:**
- `last_completed` data model: covered in Tasks 5 + 6
- Card treatment (sparkles + pill + muted text + divider): covered in Tasks 1 + 3
- S3 sparkles (5 glyphs, staggered animation, two-tone): covered in Tasks 1 + 3
- D4 pill (gradient, font, border, shadow, dark mode): covered in Task 1
- Session closure in Pick Up Here (wins list, only when wins exist): covered in Tasks 2 + 4
- `prefers-reduced-motion` gate for sparkle animation: covered in Task 1
- CLAUDE.md protocol update: covered in Task 6
- Out-of-scope items (no browser write-back, no animation on wins list, no dismiss): nothing added that would enable these

**Placeholder scan:** No TBD or TODO present.

**Type consistency:** `last_completed` is referenced as a string field consistently across all tasks. `data.chats` accessed directly in Task 4 (consistent with how `filteredChats()` accesses the same array). `esc()` used on all user-provided text.
