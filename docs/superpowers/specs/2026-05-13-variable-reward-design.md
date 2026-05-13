# Variable Reward — Win of the Day

**Date:** 2026-05-13
**Status:** Approved — ready for implementation

---

## What it does

On every page load, the shipped sidebar shows a "Win of the day" block at the top — a random past shipped item, consistent for the full calendar day. The same win appears all day, then rotates automatically at midnight. No user action needed.

The goal is a low-key dopamine hit: a quiet reminder of something real that got shipped.

---

## Data source

`chats[]` in `dashboard-data.json` where `status === "shipped"`. Each shipped chat provides:

- `title` — the win name
- `project` (or derived from chat metadata) — project label
- `updated` — display date
- `breadcrumb` — one-line summary of what was actually accomplished

If there are no shipped items, the block is omitted entirely.

---

## Pick logic

A date-seeded deterministic hash — no localStorage, no server, no state:

```js
function getWinOfTheDay(shippedItems) {
  const seed = new Date().toISOString().slice(0, 10); // "2026-05-13"
  const hash = [...seed].reduce((acc, c) => acc + c.charCodeAt(0), 0);
  return shippedItems[hash % shippedItems.length];
}
```

Same date string → same hash → same index → same item. Rotates at midnight with no intervention.

---

## UI

### Placement

Top of the shipped sidebar (`renderSidebar()`), injected before the existing shipped list.

### Structure

```
┌─────────────────────────────┐
│ ✦ WIN OF THE DAY            │  ← monospace, 9px, uppercase, gold (#a07b28)
│ PiHole — redundant setup    │  ← title, 12px, medium weight
│ Homelab · Apr 27            │  ← monospace, 10px, muted
│ ─────────────────────────── │  ← faint gold top-border separator
│ Primary/secondary failover… │  ← breadcrumb, 11px, italic, muted
└─────────────────────────────┘
```

### Styling

- Background: `var(--shipped-bg)` (`#faf5e8` light / `#2a2210` dark)
- Border: `0.5px solid var(--shipped-gold)`
- Border radius: 8px
- New CSS class: `.win-block`

### Animation

New `@keyframes pulse-gold` — 3 iterations on load, then settles:

```css
@keyframes pulse-gold {
  0%, 100% { box-shadow: 0 0 0 0px rgba(160,123,40,0); }
  50%       { box-shadow: 0 0 0 3px rgba(160,123,40,0.3), 0 0 16px rgba(160,123,40,0.2); }
}
```

Applied as `animation: pulse-gold 2s ease-in-out 3`.

---

## Implementation scope

Changes are confined to `index.html`:

1. Add `getWinOfTheDay()` helper function in the JS section
2. Add `.win-block` CSS class and `@keyframes pulse-gold` in the `<style>` block
3. Call `getWinOfTheDay()` inside `renderSidebar()` and inject the block at the top of the sidebar HTML

No changes to `dashboard-data.json` or any other file.

---

## Edge cases

- **No shipped items:** omit the block entirely — no empty state needed
- **One shipped item:** always shows the same item every day (acceptable)
- **Dark mode:** uses existing CSS vars, inherits automatically
