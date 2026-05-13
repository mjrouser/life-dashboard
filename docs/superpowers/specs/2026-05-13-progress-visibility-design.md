# Progress Visibility — Design Spec
**Date:** 2026-05-13  
**Status:** Approved

## Summary

Add a compact progress row below the filter pills showing shipped/total chats per project. Dopamine feature — lets the user see momentum across all projects at a glance.

## What it does

- Renders one row per project: emoji + name + mini progress bar + `shipped/total` fraction
- Bar fill = `shipped count ÷ total chats` for that project
- Color: `--shipped-gold` (consistent with trophy sidebar)
- When a project filter pill is active, row collapses to show only that project
- No new data fields — computed from existing `chats[]` at render time

## Visual

```
Progress ───────────────────────
⚙ Personal OS  ████████░░░  2/5
🖥 Homelab      █████░░░░░░  3/7
🏠 320 Sycamore ░░░░░░░░░░░  0/3
💼 Career       ██░░░░░░░░░  1/4
👨‍👩‍👧 Family       ░░░░░░░░░░░  0/2
```

## Design tokens

- Bar: 60px wide, 4px tall, border-radius 2px
- Fill: `--shipped-gold`
- Track: `--border`
- Label: IBM Plex Mono, 11px, `--text-tertiary`
- Fraction: IBM Plex Mono, 11px, `--text-secondary`
- Section header: same mono uppercase style as other section headers
- Placement: between filter pills and energy legend

## Implementation notes

- New `renderProgressRow()` function in `index.html` JS
- New `.progress-row`, `.progress-item`, `.progress-bar-wrap`, `.progress-bar-fill` CSS classes
- Inserted into `render()` after filter pills, before energy legend
- Hides row entirely if all projects have 0 total chats (edge case)
