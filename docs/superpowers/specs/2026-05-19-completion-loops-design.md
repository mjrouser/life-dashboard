# Completion Loops — Design Spec
**Date:** 2026-05-19
**Status:** Approved

---

## What we're building

Two interlocking features that close the loop on completed work:

1. **Card treatment** — each card that has a completed step shows it visually above the next step, with a celebratory "done" pill and animated sparkles.
2. **Session closure** — the Pick Up Here card gains a "done today" section showing all steps completed this session. Only visible on days where work was logged.

---

## Data model

Add one new optional field to chat entries in `dashboard-data.json`:

```json
"last_completed": "Configure IPv4 failover with keepalived"
```

- Set by Claude Code during session wrap: when `next_step` is updated, save the old value as `last_completed`
- Absence of the field (or `null`) means no completed step to show — card renders as normal
- "Done today" is derived at render time: cards where `last_completed` is set AND `updated` === today's date (YYYY-MM-DD)
- No new date field needed — `updated` already captures when a card was last touched

**Session wrap protocol addition:** When writing a new `next_step` during session wrap, also write the old `next_step` value to `last_completed`. This is the only data source for both features.

---

## Card treatment

When a card has `last_completed` set, a completed row appears above the existing next step line.

**Layout (top to bottom within card):**
1. Completed row: sparkles + pill + muted step text
2. Hairline divider (`0.5px`, `--border` color)
3. Next step row (existing, unchanged)

**Sparkles (S3 style):**
- 5 `✦` glyphs positioned absolutely above the pill
- Two-tone: gold (`--shipped-gold`) and green (`--accent`)
- Varied sizes (8px–13px) and opacities (0.55–1.0) for layered depth
- Staggered fade-up animation on load (`sparkle-rise` keyframe, 0.5s, delays 0–0.18s)
- Positioned above the pill, not to the side

**"Done" pill (D4 style):**
- Text: `✓ done`
- Font: IBM Plex Mono, 10px, weight 600
- Background: `linear-gradient(135deg, #e8f4ef 0%, #d4edde 100%)`
- Border: `1px solid rgba(29,107,84,0.3)`
- Box shadow: `0 1px 3px rgba(29,107,84,0.15)`
- Color: `--accent`
- Padding: `2px 7px`, border-radius: `4px`
- Dark mode: background `linear-gradient(135deg, #0f2e23 0%, #122a20 100%)`, border `rgba(93,202,165,0.3)`, shadow `0 1px 3px rgba(93,202,165,0.1)`

**Completed step text:**
- Color: `--text-secondary` (muted)
- Same font size as next step text (13px)

Cards without `last_completed` render identically to today — no change.

---

## Session closure (Pick Up Here card)

When one or more cards have `last_completed` AND `updated` === today, the Pick Up Here card gains a "done today" section below the existing content.

**Layout:**
- Hairline divider below the last existing line in the card
- Label: `✦ done today` — IBM Plex Mono, 11px, `--text-tertiary`, muted
- One line per win: `[Thread title]` in `--accent` (light weight) + ` — ` + completed step text in `--text-secondary`

**Behavior:**
- Entirely absent when no wins exist for today — card looks identical to current state
- Read-only; no interaction
- Win order: same order as cards appear in `dashboard-data.json`

---

## Implementation scope

1. **`dashboard-data.json`** — add `last_completed` field protocol to session wrap; no changes to existing entries required at implementation time (field is optional)
2. **`index.html` CSS** — add `.sparkle-wrap`, `.sparkle-rise` keyframe, `.done-pill`, `.completed-row`, `.divider-line`, `.done-today-section` styles (light + dark)
3. **`index.html` JS** — in card render loop: when `last_completed` is set, prepend completed row with sparkles, pill, muted text, and divider before next step; in Pick Up Here render: when wins exist for today, append divider + done-today section listing each win
4. **`CLAUDE.md`** — update session wrap protocol: "when updating `next_step`, also set `last_completed` to the previous `next_step` value"

---

## Out of scope

- No interactive checkoff from the browser (no write-back to JSON)
- No animation on the Pick Up Here wins list (static, not sparkled)
- No "clear" or "dismiss" for completed rows — they persist until the next session wrap overwrites `last_completed`
