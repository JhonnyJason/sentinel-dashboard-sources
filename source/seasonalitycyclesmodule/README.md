# seasonalitycyclesmodule

Lets the user define the cycle to analyse (unit, size, anchor) and shows the history range chunked into that cycle as a compact table.
It lives inside `#timeframecycles-details-container` of `seasonalityframemodule`.

- `cyclemath.coffee`: pure logic with no DOM. Covers period keys and labels, cycle math, `buildGrid` and the editor-state transitions. Tested in `testing/unittests/seasonalitycyclesmodule/`.
- `seasonalitycyclesmodule.coffee`: DOM wiring, presets and table rendering.

## Interface
- `setRange(from, to)`: `"YYYY-MM-DD"`, inclusive. Invalid dates show the no-data message.
- `setUnit(unit)`: called by the frame when the chart timeframe changes. A real change resets to "Kein Zyklus", and only presets of that unit are offered. Usable units: years, quarters, months, weeks.
- `deactivate()`: back to "Kein Zyklus" without emitting (the frame reloads anyway), e.g. on the screener jump.
- `getCycle()`: returns `{ name, unit, size, anchor, labels, included }`, or `null` when "Kein Zyklus" is selected or the definition is incomplete. `included[pos]` = the position is checked in the table header.
- For the analysis (`cyclemath`): `includedChunkFn(cycle, refYmd)` → `(k) -> boolean` per chunk age, `isFullCycle(cycle)`, `displayAges(cycle, isIncluded)` → `[1, 0]` (continuous) or `[d]` (single, d = newest included age). See `seasonalitychartmodule/README.md` for the display modes.
- `setOnChangeListener(fn)`: fires only on commit (size change, slider release, label commit, checkbox, preset selection, save, delete), never while dragging.

## Non-obvious parts
- **Anchor is a slider position.** The state keeps `k` (the position of today's period), and anchor = today's period − k. The slider is mirrored (value = size − 1 − k), so dragging right moves the anchor later. The anchor is therefore always the start of the current cycle. A stored or preset anchor is normalized on load.
- **Period index** (UTC math): years `y`, quarters `y*4+q-1`, months `y*12+m-1`, weeks `floor((days since epoch − 4)/7)` (ISO weeks start on Monday).
- **Keys**: `2026`, `2026-Q4`, `2026-10`, and for weeks the date of the Monday `2026-10-12`.
- **Compact table.** Only the 2 newest cycles are rendered, which is enough to cover every position. A last row stands for the rest, per column: the label if exactly one period is hidden, `⋮` if several, else empty (coloured when included). `buildGrid` still returns all rows.
- **Presets.** The fixed ones are defined in the module: one per cycle position (e.g. "US Midterm-Jahr"), same size, anchor and labels, only that position included. User presets are stored via `statemodule` under `seasonalitycycles-user-presets` and validated when loaded, since localStorage is a trust boundary. Presets without `included` load with all positions checked. Sizes are capped by `MAX_SIZE` (years 20, else 32); stored presets beyond that are dropped.
- **Edit vs. selected preset.** Every edit turns the state into an unsaved Benutzerdefiniert. `base` remembers the selected preset, so reverting all edits selects it again. `origin` is the custom preset the state came from: it may be overwritten on save and stays deletable while edited.
- **Picking Benutzerdefiniert** starts fresh: `customDefault(unit)` – size 4 years / 4 quarters / 6 months / 7 weeks, all positions included, the current period at position 0.
- **Name warning** ("Name existiert bereits") only when an otherwise possible save is blocked by the name.
- **Delete takes two clicks.** The first unlocks the button for 10 s and discards edits (shows what gets deleted), the second deletes. Any other change locks again. Afterwards the first preset of the unit is selected, or "Kein Zyklus" if there is none.
- **Styling.** `.edit-group` (underline + edit icon) comes from `eventscreenerframemodule`. Rules here are prefixed with `#seasonalitycycles` to outrank the general input rules and `reset.styl`'s `button:hover`.

## SPEC.md
`SPEC.md` describes the originally planned portable component and is still the reference for the behaviour (§4 arithmetic, §6 editor, §9 examples).
`docs/` is obsolete.
Deviations: a plain module (no Shadow DOM or class contract), rows orientation only, the compact table, no throwing input validation, smaller `MAX_SIZE`, and the position checkboxes.
