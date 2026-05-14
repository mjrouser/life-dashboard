# Tiny Bets — Design Spec
**Date:** 2026-05-14
**Status:** Approved

---

## What we're building

A lightweight way to mark certain work threads as "tiny bets" — low-commitment, learning-focused experiments that aren't full projects but deserve a home on the dashboard. Tiny bets are visually distinguishable from committed work and filterable.

---

## Data model

Add a `"tiny_bet": true` field to any chat entry in `dashboard-data.json`. Absence of the field (or `false`) means normal card behavior.

**Tagged chats (initial set):**
- `what-now-app`
- `discord-bot`
- `linkedin-content`
- `home-assistant`
- `spotify-playlist`

---

## Card treatment — Option A (subtle tag)

A `🧪 tiny bet` chip appears in the meta row of the card, alongside the breadcrumb and energy dot. No structural change to the card layout.

**Chip style:**
- Font: IBM Plex Mono, 10px
- Color: `#7a7a74` (text), `rgba(0,0,0,0.04)` (background)
- Border: `0.5px solid rgba(0,0,0,0.1)`
- Padding: `2px 7px`, border-radius: `6px`
- Dark mode: text `#a3a39d`, background `rgba(255,255,255,0.06)`, border `rgba(255,255,255,0.1)`

---

## Filter pill

A `🧪 Tiny bets` pill is appended to the existing project filter row, separated from project pills by a thin vertical divider.

**Pill behavior:**
- Always visible, inactive by default
- Clicking toggles a `tinyBetFilter` boolean (independent of `activeFilter`)
- When active: filters cards to only those with `tiny_bet: true`; stacks with any active project filter
- Active pill color: `#8b7ec8` background, `#fff` text, `#8b7ec8` border

**Divider style:**
- `0.5px` wide, `16px` tall, `rgba(0,0,0,0.1)` color, `2px` margin each side

---

## Filter interaction

The tiny bet filter stacks with the project filter using AND logic: if "Personal OS" + "Tiny bets" are both active, only Personal OS tiny bets show. If only "Tiny bets" is active, all tiny bets across all projects show.

---

## Implementation scope

1. `dashboard-data.json`: add `"tiny_bet": true` to 5 chat entries
2. `index.html` CSS: add `.bet-tag` chip styles (light + dark)
3. `index.html` JS: add `tinyBetFilter` state variable; update filter render to include divider + tiny bets pill; update card render to show `.bet-tag` chip when `tiny_bet: true`; update `filterChats()` to apply tiny bet filter
