# FlexHD Outdoor AP — Installation Plan & Bill of Materials

## Project Overview

Mount a Ubiquiti FlexHD (UAP-FlexHD) access point on the exterior of the west-facing wall, fed by PoE from the basement switch through an existing (or new) wall penetration.

**Total cable run:** ~20–25 feet (switch → wall penetration → up exterior wall → AP)
**Power:** PoE from switch (no separate adapter needed)

---

## The Three Segments

### Segment 1: Inside Basement (Switch → Wall Penetration)
- ~10–15 ft of indoor Cat6 patch cable along the basement wall
- Route along the wall using cable clips or J-hooks
- Connect to the surge protector near the wall penetration point

### Segment 2: Through the Wall
- Existing fiber penetration is on the stucco section, near the fiber/cable boxes
- If hole is too tight for Cat6 alongside fiber, drill a dedicated 3/8" hole to the right of existing — aligned with planned conduit path
- Seal penetration with duct seal putty on both sides

### Segment 3: Exterior Wall (Penetration → AP)
- Conduit runs to the right of the fiber box, vertically up the wall
- **Stucco zone:** ~44.5" (ground to siding lip) — LB body at penetration, conduit up through stucco zone with Tapcon-mounted straps
- **Offset transition:** 1.5" offset at siding lip using PVC offset fittings
- **Siding zone:** Conduit continues up to weatherproof box near AP mount, straps with stainless screws
- **AP mount:** Just above the top of the window trim (~8.5–9 ft from grade), LED side up
- Short drip loop at AP connection

---

## Mounting Details

- **Height:** ~8.5–9 ft from grade — just above the top of the window trim
- **Orientation:** LED side facing UP (required for weatherproofing per Ubiquiti)
- **Mount:** Use the included outdoor wall/pole mount bracket
- **Tip:** The window header (structural beam above the window frame) provides solid framing to screw into — you'll feel solid resistance when drilling vs. hollow space

### Wall Substrates (two zones)
- **Bottom 44.5":** Stucco over lath or blocks → use Tapcon screws for conduit straps and LB body
- **Above 44.5" (siding):** Aluminum siding over old wood shingles over framing → use stainless steel screws (2–2.5" to bite through siding + shingles into sheathing). Pre-drill through aluminum to avoid dimpling. Consider a small neoprene washer or rubber pad behind straps/bracket to cushion the siding and seal screw holes.

### Conduit Transition at Siding Lip
- Siding sits **1.5" proud** of stucco face
- Use **3/4" PVC offset fittings** (pre-bent pair) to step conduit out 1.5" at the transition — cleanest look, easiest install
- Conduit route: to the right of the fiber box, straight vertical run

---

## Bill of Materials

### Cable & Connectivity
| Item | Qty | Est. Cost | Notes |
|------|-----|-----------|-------|
| Outdoor-rated Cat6 cable (CMX) | 25 ft | $10–15 | Buy a 50 ft or 100 ft box — you'll use the rest eventually. Brands: trueCABLE, Ubiquiti Tough Cable, or any CMX-rated |
| Indoor Cat6 patch cable (10–15 ft) | 1 | $5–8 | For switch to wall penetration. Pre-made is fine |

*Crimper and RJ45 ends already on hand. Terminating after pull to keep the wall penetration hole small.*

### Conduit & Weatherproofing (Exterior Run)
| Item | Qty | Est. Cost | Notes |
|------|-----|-----------|-------|
| 3/4" Schedule 40 PVC conduit (10 ft stick) | 1 | $4–6 | Cut to length for your vertical run |
| 3/4" PVC conduit straps (2-hole) | 3–4 | $2–3 | Secure conduit to wall every ~3 ft |
| 3/4" PVC LB conduit body | 1 | $6–8 | Goes at the bottom where cable exits wall and turns up. Keeps water out of the turn |
| 3/4" PVC conduit coupling | 1 | $1 | If needed for joining sections |
| 3/4" weatherproof box (single-gang) | 1 | $5–8 | At the top of the conduit run, near the AP mount |
| PVC conduit cement/glue | 1 | $4–5 | Small can, bonds PVC joints |
| Duct seal putty | 1 | $3–5 | Seals the wall penetration from both sides |
| Silicone caulk (exterior grade) | 1 | $5–7 | Seal around conduit attachments to wall |

### Surge Protection & Grounding
| Item | Qty | Est. Cost | Notes |
|------|-----|-----------|-------|
| Ubiquiti ETH-SP-G2 surge protector | 1 | $12.50 | Install inline on the interior side, near wall penetration |
| #10 solid copper wire | 5–10 ft | $3–5 | Ground run from ETH-SP-G2 ground lug to existing ground wire |
| Split bolt connector | 1 | $3–5 | Couples #10 copper to existing ground wire between panel and ground stake |

### Fasteners & Mounting
| Item | Qty | Est. Cost | Notes |
|------|-----|-----------|-------|
| Tapcon concrete screws (3/16" x 1-3/4") | 4–6 | $8–10 | For lower stucco/masonry zone (conduit straps, LB body) |
| Masonry drill bit (3/16") | 1 | — | Already purchased. Use with hammer drill for Tapcon pilot holes into stucco/masonry |
| Stainless steel screws (2–2.5") | 6–8 | $5–8 | For upper siding zone (conduit straps, AP bracket). Pre-drill through aluminum |
| Neoprene washers or rubber pads | 4–6 | $3–5 | Behind straps/bracket on siding — cushions aluminum and seals screw holes |
| 3/4" PVC offset fittings (pair) | 1 set | $4–6 | 1.5" offset at stucco-to-siding transition — confirmed measurement |
| Cable clips / J-hooks | 5–6 | $3–5 | For routing the indoor cable along the basement wall |

### Tools You'll Need (Likely Have Most)
- Drill/driver
- Hammer drill or impact driver (for Tapcons into masonry — regular drill can work with masonry bit, just slower)
- Level
- Tape measure
- Hacksaw or PVC cutter (to cut conduit to length)
- Ladder (need to reach 8–10 ft)
- Pencil for marking

---

## Estimated Total Cost

| Category | Range |
|----------|-------|
| Cable & connectivity | $15–25 |
| Conduit & weatherproofing | $25–35 |
| Surge protector & grounding | $20–25 |
| Fasteners & offset fittings | $25–35 |
| **Total** | **~$85–120** |

*Crimper and RJ45 ends already on hand — not included above.*

---

## Installation Sequence

1. **Plan & measure** — Confirm AP mounting spot, measure the vertical run, check the existing hole for clearance, measure siding lip depth for offset fittings
2. **Drill (if needed)** — Drill dedicated 3/8" hole for ethernet if the fiber hole is too tight
3. **Mount conduit** — Install LB body at bottom (Tapcons into stucco), conduit vertically with offset at siding lip, weatherproof box at top (stainless screws into siding). Straps every ~3 ft
4. **Pull cable** — Feed unterminated outdoor Cat6 through wall and up through conduit
5. **Terminate cable** — Crimp RJ45 ends on both sides after the pull
6. **Route inside** — Connect to indoor patch cable run to switch
7. **Seal everything** — Duct seal putty in the wall hole (both sides), silicone around conduit straps and wall attachments
8. **Install surge protector** — Inline on the indoor side, ground it properly
9. **Mount the AP** — Attach bracket (stainless screws, neoprene behind), connect cable, seat the AP (LED side up)
10. **Test** — Power on, verify AP appears in UniFi controller, test signal in yard
11. **Clean up** — Tidy cable routing inside, confirm all seals are solid

---

## Decision Points to Resolve Before Install Day

- [ ] Check existing fiber hole — room for Cat6 alongside, or drill new hole to the right (aligned with conduit path)
- [x] ~~Confirm exact mounting height for AP~~ → ~8.5–9 ft, just above window trim
- [x] ~~Decide: pre-made outdoor patch cable vs. bulk cable + DIY termination~~ → DIY, crimping after pull
- [x] ~~Check what's behind the stucco at mounting locations~~ → Bottom 44.5" is stucco over lath/blocks (Tapcons); upper is aluminum siding over wood shingles (stainless screws)
- [ ] Verify switch has an available PoE port and confirm PoE standard (802.3af is what the FlexHD needs)
- [x] ~~Measure siding lip depth~~ → 1.5" offset, standard PVC offset fittings will work
- [x] ~~Measure exact heights~~ → 44.5" stucco zone; window top edge ~8 ft from grade

---

*Project workspace: Home Improvement — Lawn, Garden & Outdoor*
*Created: May 2026*
