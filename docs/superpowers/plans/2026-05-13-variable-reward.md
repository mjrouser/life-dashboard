# Variable Reward — Win of the Day Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a "Win of the day" block at the top of the shipped sidebar — a random past shipped item, consistent for the full calendar day, with a 3-pulse gold glow on load.

**Architecture:** All changes are confined to `index.html`. A date-seeded hash picks one shipped item per day deterministically. The win block is injected at the top of `renderSidebar()` before the existing shipped list. No storage, no server, no new dependencies.

**Tech Stack:** Vanilla JS, CSS custom properties, HTML. No build step. Local dev via `python3 -m http.server 8080`.

---

## File Map

- **Modify:** `index.html:300–360` — add `.win-block` CSS classes and `@keyframes pulse-gold`
- **Modify:** `index.html:579–584` — add `formatShortDate()` and `getWinOfTheDay()` helpers after `trophySvg()`
- **Modify:** `index.html:782–819` — update `renderSidebar()` to inject win block at top

---

## Task 1: Add CSS for win block

**Files:**
- Modify: `index.html:356–359` — insert after the `@media (prefers-reduced-motion)` block

- [ ] **Step 1: Add the win block styles**

Find this block in `index.html` (around line 356):

```css
  @media (prefers-reduced-motion: no-preference) {
    .ship-celebrate { animation: ship-in 0.4s ease-out both; }
    .ship-celebrate .shipped-badge { animation: trophy-bounce 0.5s ease-in-out 0.4s both; }
  }
```

Insert the following immediately after it (before the `/* ── Heatmap ── */` comment):

```css
  /* ── Win of the Day ── */
  .win-block {
    background: var(--shipped-bg);
    border: 0.5px solid var(--shipped-gold);
    border-radius: 8px;
    padding: 10px 12px;
    margin-bottom: 16px;
  }
  .win-block-label {
    font-family: var(--mono);
    font-size: 9px;
    text-transform: uppercase;
    letter-spacing: 0.07em;
    color: var(--shipped-gold);
    font-weight: 500;
    margin-bottom: 4px;
  }
  .win-block-title {
    font-size: 12px;
    font-weight: 500;
    color: var(--text);
    margin-bottom: 2px;
  }
  .win-block-meta {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--text-tertiary);
  }
  .win-block-breadcrumb {
    font-size: 11px;
    color: var(--text-secondary);
    font-style: italic;
    margin-top: 6px;
    padding-top: 6px;
    border-top: 0.5px solid rgba(160, 123, 40, 0.25);
  }

  @keyframes pulse-gold {
    0%, 100% { box-shadow: 0 0 0 0px rgba(160,123,40,0); }
    50% { box-shadow: 0 0 0 3px rgba(160,123,40,0.3), 0 0 16px rgba(160,123,40,0.2); }
  }

  @media (prefers-reduced-motion: no-preference) {
    .win-block { animation: pulse-gold 2s ease-in-out 3; }
  }
```

- [ ] **Step 2: Verify the CSS was inserted correctly**

Run: `grep -n "win-block" index.html`

Expected: 7–8 lines with `.win-block`, `.win-block-label`, `.win-block-title`, etc.

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: add win-block CSS and pulse-gold animation"
```

---

## Task 2: Add JS helpers

**Files:**
- Modify: `index.html:584` — insert after `trophySvg()` function (closing `}` around line 584)

- [ ] **Step 1: Add the two helper functions**

Find this function in `index.html` (around line 579):

```js
function trophySvg() {
  return `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M8 21h8M12 17v4M7 4H4a1 1 0 0 0-1 1v2a4 4 0 0 0 4 4h1M17 4h3a1 1 0 0 1 1 1v2a4 4 0 0 1-4 4h-1" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M7 4h10v7a5 5 0 0 1-10 0V4Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
  </svg>`;
}
```

Insert the following immediately after the closing `}`:

```js
function formatShortDate(dateStr) {
  return new Date(dateStr + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

function getWinOfTheDay(shippedItems) {
  if (shippedItems.length === 0) return null;
  const seed = new Date().toISOString().slice(0, 10); // "2026-05-13"
  const hash = [...seed].reduce((acc, c) => acc + c.charCodeAt(0), 0);
  return shippedItems[hash % shippedItems.length];
}
```

- [ ] **Step 2: Verify the functions exist**

Run: `grep -n "getWinOfTheDay\|formatShortDate" index.html`

Expected: 2 function definitions.

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: add getWinOfTheDay and formatShortDate helpers"
```

---

## Task 3: Inject win block into sidebar

**Files:**
- Modify: `index.html:782–819` — update `renderSidebar()` to call `getWinOfTheDay()` and prepend the block

- [ ] **Step 1: Update `renderSidebar()` to inject the win block**

Find this code in `renderSidebar()` (around line 785):

```js
  const sidebar = document.getElementById('shipped-sidebar');
  const streak = calcStreak(activityLog);
  let html = '';

  // Shipped items
  if (shipped.length > 0) {
```

Replace with:

```js
  const sidebar = document.getElementById('shipped-sidebar');
  const streak = calcStreak(activityLog);
  let html = '';

  // Win of the day
  const win = getWinOfTheDay(shipped);
  if (win) {
    html += `<div class="win-block">
      <div class="win-block-label">✦ Win of the day</div>
      <div class="win-block-title">${esc(win.title)}</div>
      <div class="win-block-meta">${projectShort(win.project_id)} · ${formatShortDate(win.updated)}</div>
      ${win.breadcrumb ? `<div class="win-block-breadcrumb">${esc(win.breadcrumb)}</div>` : ''}
    </div>`;
  }

  // Shipped items
  if (shipped.length > 0) {
```

- [ ] **Step 2: Start local server and verify in browser**

```bash
python3 -m http.server 8080
```

Open `http://localhost:8080` in a browser.

Expected:
- A gold-bordered card appears at the top of the sidebar, above the "Shipped" list
- Label reads "✦ WIN OF THE DAY" in gold monospace
- Shows one of the two shipped items (PiHole redundant setup or Homelab status page)
- Breadcrumb appears below a faint gold divider line, in italic
- The block pulses with a gold glow 3 times, then settles
- Reloading the page on the same day shows the same item
- Dark mode: open browser DevTools → Rendering → "Emulate CSS media feature prefers-color-scheme: dark" — block should use dark gold vars

- [ ] **Step 3: Verify reduced motion respect**

In DevTools → Rendering → "Emulate CSS media feature prefers-reduced-motion: reduce".

Expected: block appears with no animation (no pulse).

- [ ] **Step 4: Commit and push**

```bash
git add index.html
git commit -m "feat: show win of the day in shipped sidebar (#3)"
git push
```

---

## Self-Review Notes

- **Spec coverage:** Pick logic ✓, Content (title + project + date + breadcrumb) ✓, Placement (top of sidebar) ✓, Animation (3-pulse gold glow) ✓, Daily consistency ✓, Edge case (no shipped items → block omitted) ✓, Dark mode (CSS vars) ✓, Reduced motion ✓
- **No placeholders:** All code is complete and exact.
- **Type consistency:** `getWinOfTheDay()` returns a chat object or `null`. `win.title`, `win.project_id`, `win.updated`, `win.breadcrumb` all confirmed present in `dashboard-data.json` shipped items.
